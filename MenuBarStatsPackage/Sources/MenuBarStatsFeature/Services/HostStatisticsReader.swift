import Darwin.Mach
import Foundation

public protocol HostStatisticsReading {
    func readHostSnapshot() -> HostSummarySnapshot
}

protocol HostCPUTicksReading {
    func readCPUTicks() -> HostCPUTicks?
}

protocol HostMemoryUsageReading {
    func readMemoryUsage() -> UsageSnapshot?
}

struct HostCPUTicks: Equatable, Sendable {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64

    var total: UInt64 { user + system + idle + nice }
    var busy: UInt64 { user + system + nice }
}

public final class HostStatisticsReader: HostStatisticsReading {
    private let cpuReader: HostCPUTicksReading
    private let memoryReader: HostMemoryUsageReading
    private var previousCPUTicks: HostCPUTicks?

    public convenience init() {
        self.init(cpuReader: MachHostCPUTicksReader(), memoryReader: MachMemoryUsageReader())
    }

    init(cpuReader: HostCPUTicksReading, memoryReader: HostMemoryUsageReading) {
        self.cpuReader = cpuReader
        self.memoryReader = memoryReader
    }

    public func readHostSnapshot() -> HostSummarySnapshot {
        let cpuUsage: CPUUsageState
        if let currentTicks = cpuReader.readCPUTicks() {
            if let previousCPUTicks {
                cpuUsage = Self.cpuUsage(previous: previousCPUTicks, current: currentTicks)
            } else {
                cpuUsage = .loading
            }
            self.previousCPUTicks = currentTicks
        } else {
            cpuUsage = .loading
        }

        return HostSummarySnapshot(cpuUsage: cpuUsage, memoryUsage: memoryReader.readMemoryUsage())
    }

    static func cpuUsage(previous: HostCPUTicks, current: HostCPUTicks) -> CPUUsageState {
        let totalDelta = current.total &- previous.total
        let busyDelta = current.busy &- previous.busy
        guard totalDelta > 0 else { return .loading }
        return .value((Double(busyDelta) / Double(totalDelta)) * 100)
    }
}

private struct MachHostCPUTicksReader: HostCPUTicksReading {
    func readCPUTicks() -> HostCPUTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return HostCPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }
}

private struct MachMemoryUsageReader: HostMemoryUsageReading {
    func readMemoryUsage() -> UsageSnapshot? {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let usedPages = UInt64(stats.active_count + stats.inactive_count + stats.wire_count + stats.compressor_page_count)
        let usedBytes = usedPages * UInt64(pageSize)
        let totalBytes = ProcessInfo.processInfo.physicalMemory

        return UsageSnapshot(usedBytes: min(usedBytes, totalBytes), totalBytes: totalBytes)
    }
}
