import Foundation

public enum CPUUsageState: Equatable, Sendable {
    case loading
    case value(Double)
}

public struct UsageSnapshot: Equatable, Sendable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }

    public var fractionUsed: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }
}

public struct HostSummarySnapshot: Equatable, Sendable {
    public let cpuUsage: CPUUsageState
    public let memoryUsage: UsageSnapshot?

    public init(cpuUsage: CPUUsageState, memoryUsage: UsageSnapshot?) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
    }
}

public struct ProcessRow: Identifiable, Equatable, Sendable {
    public enum Metric: Equatable, Sendable {
        case percent(Double)
        case bytes(UInt64)
    }

    public let pid: Int32
    public let name: String
    public let metric: Metric

    public init(pid: Int32, name: String, metric: Metric) {
        self.pid = pid
        self.name = name
        self.metric = metric
    }

    public var id: Int32 { pid }
}

public struct ProcessLists: Equatable, Sendable {
    public let cpu: [ProcessRow]
    public let memory: [ProcessRow]

    public init(cpu: [ProcessRow], memory: [ProcessRow]) {
        self.cpu = cpu
        self.memory = memory
    }
}

public struct SamplingConfiguration: Equatable, Sendable {
    public let closedSummaryInterval: TimeInterval
    public let openSummaryInterval: TimeInterval
    public let openProcessInterval: TimeInterval
    public let diskRefreshInterval: TimeInterval
    public let topProcessCount: Int

    public init(
        closedSummaryInterval: TimeInterval,
        openSummaryInterval: TimeInterval,
        openProcessInterval: TimeInterval,
        diskRefreshInterval: TimeInterval,
        topProcessCount: Int
    ) {
        self.closedSummaryInterval = closedSummaryInterval
        self.openSummaryInterval = openSummaryInterval
        self.openProcessInterval = openProcessInterval
        self.diskRefreshInterval = diskRefreshInterval
        self.topProcessCount = topProcessCount
    }

    public static let v1 = SamplingConfiguration(
        closedSummaryInterval: 3,
        openSummaryInterval: 2,
        openProcessInterval: 2,
        diskRefreshInterval: 30,
        topProcessCount: 5
    )
}
