import Foundation

public enum HelperService {
    public static let machServiceName = "com.startbar.MenuBarStats.helper"
}

@objc public protocol ProcessInfoHelperProtocol {
    func cpuTime(
        forPID pid: Int32,
        withReply reply: @escaping (_ success: Bool, _ userTime: UInt64, _ systemTime: UInt64) -> Void
    )

    /// Returns JSON-encoded `TopProcessesPayload` with top-N by CPU and top-N by memory.
    /// CPU % uses ns-deltas since the previous invocation; first call after helper start yields zeros
    /// until a second sample is collected, then updates correctly.
    func topProcesses(
        limit: Int32,
        withReply reply: @escaping (_ jsonData: Data?) -> Void
    )
}

public struct WireProcessRow: Codable, Equatable, Sendable {
    public var pid: Int32
    public var name: String
    public var cpuPercent: Double
    public var memoryBytes: UInt64

    public init(pid: Int32, name: String, cpuPercent: Double, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}

public struct TopProcessesPayload: Codable, Equatable, Sendable {
    public var cpu: [WireProcessRow]
    public var memory: [WireProcessRow]

    public init(cpu: [WireProcessRow], memory: [WireProcessRow]) {
        self.cpu = cpu
        self.memory = memory
    }
}
