import Darwin
import Foundation

final class HelperXPCService: NSObject, ProcessInfoHelperProtocol {
    private let sampler = TopProcessSampler()

    func cpuTime(
        forPID pid: Int32,
        withReply reply: @escaping (Bool, UInt64, UInt64) -> Void
    ) {
        var taskInfo = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, size)
        if result == size {
            reply(true, taskInfo.pti_total_user, taskInfo.pti_total_system)
        } else {
            reply(false, 0, 0)
        }
    }

    func topProcesses(
        limit: Int32,
        withReply reply: @escaping (Data?) -> Void
    ) {
        let payload = sampler.sampleAndComputeTop(limit: Int(limit))
        reply(try? JSONEncoder().encode(payload))
    }
}

/// Enumerates every PID via `proc_listallpids` and queries `proc_pid_rusage` / `proc_pidpath`
/// to build a top-N snapshot. Keeps the prior sample so CPU % reflects the delta between the
/// two most recent calls — no background polling, only work-on-demand.
final class TopProcessSampler {
    private struct Sample {
        let userNs: UInt64
        let systemNs: UInt64
        let memoryBytes: UInt64
        let name: String
        let sampledAtNs: UInt64
    }

    /// `rusage_info_v4.ri_user_time` / `ri_system_time` are reported in mach absolute time
    /// units, not nanoseconds. On Apple Silicon the ratio is ~125/3 so ignoring it makes CPU %
    /// ~42× too small (a full core reads ~2.4%). Capture the timebase once and convert.
    private static let machTimebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private static func nanoseconds(fromMachUnits units: UInt64) -> UInt64 {
        units &* UInt64(machTimebase.numer) / UInt64(machTimebase.denom)
    }

    private let queue = DispatchQueue(label: "com.startbar.MenuBarStats.helper.sampler")
    private var previous: [pid_t: Sample] = [:]

    func sampleAndComputeTop(limit: Int) -> TopProcessesPayload {
        queue.sync {
            let current = Self.collectSamples()
            let rows = Self.buildRows(current: current, previous: previous)
            previous = current

            guard limit > 0 else {
                return TopProcessesPayload(cpu: [], memory: [])
            }

            let cpu = rows
                .sorted { lhs, rhs in
                    if lhs.cpuPercent == rhs.cpuPercent { return lhs.pid < rhs.pid }
                    return lhs.cpuPercent > rhs.cpuPercent
                }
                .prefix(limit)

            let memory = rows
                .sorted { lhs, rhs in
                    if lhs.memoryBytes == rhs.memoryBytes { return lhs.pid < rhs.pid }
                    return lhs.memoryBytes > rhs.memoryBytes
                }
                .prefix(limit)

            return TopProcessesPayload(cpu: Array(cpu), memory: Array(memory))
        }
    }

    private static func buildRows(
        current: [pid_t: Sample],
        previous: [pid_t: Sample]
    ) -> [WireProcessRow] {
        current.map { pid, sample in
            let cpu: Double
            if let prev = previous[pid], sample.sampledAtNs > prev.sampledAtNs {
                let cpuDeltaNs = (sample.userNs &- prev.userNs) &+ (sample.systemNs &- prev.systemNs)
                let wallDeltaNs = sample.sampledAtNs - prev.sampledAtNs
                cpu = wallDeltaNs > 0 ? (Double(cpuDeltaNs) / Double(wallDeltaNs)) * 100.0 : 0.0
            } else {
                cpu = 0.0
            }
            return WireProcessRow(
                pid: pid,
                name: sample.name,
                cpuPercent: max(cpu, 0),
                memoryBytes: sample.memoryBytes
            )
        }
    }

    private static func collectSamples() -> [pid_t: Sample] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [:] }

        var pids = [pid_t](repeating: 0, count: Int(count) * 2)
        let filled = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
        guard filled > 0 else { return [:] }

        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        var out: [pid_t: Sample] = [:]
        out.reserveCapacity(Int(filled))

        let pathBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(MAXPATHLEN))
        defer { pathBuffer.deallocate() }
        let nameBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: 1024)
        defer { nameBuffer.deallocate() }

        for i in 0..<Int(filled) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var rusage = rusage_info_current()
            let rusageResult = withUnsafeMutablePointer(to: &rusage) { ptr -> Int32 in
                ptr.withMemoryRebound(to: Optional<rusage_info_t>.self, capacity: 1) { rebound in
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, rebound)
                }
            }
            guard rusageResult == 0 else { continue }

            let name = Self.processName(
                pid: pid,
                pathBuffer: pathBuffer,
                nameBuffer: nameBuffer
            )

            out[pid] = Sample(
                userNs: Self.nanoseconds(fromMachUnits: rusage.ri_user_time),
                systemNs: Self.nanoseconds(fromMachUnits: rusage.ri_system_time),
                memoryBytes: rusage.ri_resident_size,
                name: name,
                sampledAtNs: now
            )
        }

        return out
    }

    private static func processName(
        pid: pid_t,
        pathBuffer: UnsafeMutablePointer<CChar>,
        nameBuffer: UnsafeMutablePointer<CChar>
    ) -> String {
        let pathLen = proc_pidpath(pid, pathBuffer, UInt32(MAXPATHLEN))
        if pathLen > 0 {
            let full = String(cString: pathBuffer)
            let component = (full as NSString).lastPathComponent
            if !component.isEmpty { return component }
        }
        let nameLen = proc_name(pid, nameBuffer, 1024)
        if nameLen > 0 {
            let name = String(cString: nameBuffer)
            if !name.isEmpty { return name }
        }
        return "PID \(pid)"
    }
}

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: ProcessInfoHelperProtocol.self)
        connection.exportedObject = HelperXPCService()
        connection.resume()
        return true
    }
}

@main
enum HelperMain {
    static func main() {
        let delegate = HelperDelegate()
        let listener = NSXPCListener(machServiceName: HelperService.machServiceName)
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}
