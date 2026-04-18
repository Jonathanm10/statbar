import Foundation
import OSLog

private let processListPerformanceLog = OSLog(subsystem: "MenuBarStats", category: "Performance")

@discardableResult
private func withProcessListSignpost<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
    let signpostID = OSSignpostID(log: processListPerformanceLog)
    os_signpost(.begin, log: processListPerformanceLog, name: name, signpostID: signpostID)
    defer { os_signpost(.end, log: processListPerformanceLog, name: name, signpostID: signpostID) }
    return try body()
}

public protocol ProcessListProviding {
    func topProcesses(limit: Int) -> ProcessLists
}

/// Abstraction over a root-privileged source of per-process CPU/memory. When present, it is
/// preferred over the `ps` fallback because it exposes stats for System Extensions (e.g.
/// `com.crowdstrike.falcon.Agent`) that `ps` always reports as zero.
public protocol PrivilegedProcessListFetching {
    /// Returns rows for top-N by CPU and memory, or `nil` if the privileged source is
    /// unavailable so the caller can fall back. Implementations must be cheap and non-blocking
    /// beyond a short timeout.
    func fetchTopProcesses(limit: Int) -> ProcessLists?
}

protocol CommandRunning {
    func run(executable: String, arguments: [String]) throws -> String
}

struct ShellCommandRunner: CommandRunning {
    func run(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errorOutput = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw ProcessListError.commandFailed(errorOutput.isEmpty ? output : errorOutput)
        }

        return output
    }
}

enum ProcessListError: Error {
    case commandFailed(String)
}

public final class ProcessListProvider: ProcessListProviding {
    private let commandRunner: CommandRunning
    private let privilegedFetcher: PrivilegedProcessListFetching?
    private let clock: () -> TimeInterval
    private var previousSamples: [Int32: PriorSample] = [:]

    public convenience init() {
        self.init(commandRunner: ShellCommandRunner(), privilegedFetcher: nil)
    }

    public convenience init(privilegedFetcher: PrivilegedProcessListFetching?) {
        self.init(commandRunner: ShellCommandRunner(), privilegedFetcher: privilegedFetcher)
    }

    init(
        commandRunner: CommandRunning,
        privilegedFetcher: PrivilegedProcessListFetching? = nil,
        clock: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }
    ) {
        self.commandRunner = commandRunner
        self.privilegedFetcher = privilegedFetcher
        self.clock = clock
    }

    public func topProcesses(limit: Int) -> ProcessLists {
        guard limit > 0 else {
            return ProcessLists(cpu: [], memory: [])
        }

        if let privileged = privilegedFetcher?.fetchTopProcesses(limit: limit) {
            return privileged
        }

        do {
            let output = try withProcessListSignpost("TopProcessList") {
                try commandRunner.run(
                    executable: "/bin/ps",
                    arguments: ["-Aceo", "pid=,pcpu=,time=,rss=,comm="]
                )
            }
            let rawRows = Self.parsePSOutput(output)
            let now = clock()
            let prior = previousSamples
            var nextSamples: [Int32: PriorSample] = [:]
            nextSamples.reserveCapacity(rawRows.count)

            let rows: [ProcessSample] = rawRows.map { raw in
                let cpuPercent: Double
                if let previous = prior[raw.pid], now > previous.timestamp {
                    let elapsed = now - previous.timestamp
                    let deltaCpu = max(0, raw.cpuSeconds - previous.cpuSeconds)
                    cpuPercent = (deltaCpu / elapsed) * 100
                } else {
                    cpuPercent = raw.pcpuLifetime
                }
                nextSamples[raw.pid] = PriorSample(cpuSeconds: raw.cpuSeconds, timestamp: now)
                return ProcessSample(
                    pid: raw.pid,
                    name: raw.name,
                    cpuPercent: cpuPercent,
                    memoryBytes: raw.memoryBytes
                )
            }

            previousSamples = nextSamples

            let topCPU = rows
                .sorted { lhs, rhs in
                    if lhs.cpuPercent == rhs.cpuPercent {
                        return lhs.pid < rhs.pid
                    }
                    return lhs.cpuPercent > rhs.cpuPercent
                }
                .prefix(limit)
                .map(\.cpuRow)

            let topMemory = rows
                .sorted { lhs, rhs in
                    if lhs.memoryBytes == rhs.memoryBytes {
                        return lhs.pid < rhs.pid
                    }
                    return lhs.memoryBytes > rhs.memoryBytes
                }
                .prefix(limit)
                .map(\.memoryRow)

            return ProcessLists(cpu: Array(topCPU), memory: Array(topMemory))
        } catch {
            return ProcessLists(cpu: [], memory: [])
        }
    }

    struct PriorSample: Equatable {
        let cpuSeconds: Double
        let timestamp: TimeInterval
    }

    struct ProcessSample: Equatable {
        let pid: Int32
        let name: String
        let cpuPercent: Double
        let memoryBytes: UInt64

        var cpuRow: ProcessRow {
            ProcessRow(pid: pid, name: name, metric: .percent(cpuPercent))
        }

        var memoryRow: ProcessRow {
            ProcessRow(pid: pid, name: name, metric: .bytes(memoryBytes))
        }
    }

    struct RawProcessSample: Equatable {
        let pid: Int32
        let name: String
        let pcpuLifetime: Double
        let cpuSeconds: Double
        let memoryBytes: UInt64
    }

    static func parsePSOutput(_ output: String) -> [RawProcessSample] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
    }

    private static func parseLine(_ line: String) -> RawProcessSample? {
        let parts = line.split(maxSplits: 4, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        guard
            parts.count >= 4,
            let pid = Int32(parts[0]),
            let pcpu = Double(parts[1]),
            let cpuSeconds = parseCpuTime(String(parts[2])),
            let rssInKilobytes = UInt64(parts[3])
        else {
            return nil
        }

        let rawName = parts.count == 5 ? String(parts[4]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let displayName = rawName.isEmpty ? "PID \(pid)" : URL(fileURLWithPath: rawName).lastPathComponent

        return RawProcessSample(
            pid: pid,
            name: displayName,
            pcpuLifetime: pcpu,
            cpuSeconds: cpuSeconds,
            memoryBytes: rssInKilobytes * 1024
        )
    }

    static func parseCpuTime(_ value: String) -> Double? {
        let components = value.split(separator: ":")
        guard !components.isEmpty else { return nil }
        var seconds: Double = 0
        for component in components {
            guard let part = Double(component) else { return nil }
            seconds = seconds * 60 + part
        }
        return seconds
    }
}
