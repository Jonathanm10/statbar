import Testing
@testable import MenuBarStatsFeature

struct HostStatisticsReaderTests {
    @Test func cpuDeltaTransitionsFromLoadingToValue() {
        let cpuReader = StubCPUTicksReader([
            HostCPUTicks(user: 100, system: 100, idle: 800, nice: 0),
            HostCPUTicks(user: 150, system: 150, idle: 900, nice: 0)
        ])
        let memoryReader = StubMemoryUsageReader(snapshot: UsageSnapshot(usedBytes: 400, totalBytes: 1000))
        let subject = HostStatisticsReader(cpuReader: cpuReader, memoryReader: memoryReader)

        let first = subject.readHostSnapshot()
        #expect(first.cpuUsage == .loading)
        #expect(first.memoryUsage == UsageSnapshot(usedBytes: 400, totalBytes: 1000))

        let second = subject.readHostSnapshot()
        guard case let .value(value) = second.cpuUsage else {
            Issue.record("Expected sampled CPU value")
            return
        }

        #expect(abs(value - 50) < 0.001)
    }
}

private final class StubCPUTicksReader: HostCPUTicksReading {
    private var snapshots: [HostCPUTicks?]

    init(_ snapshots: [HostCPUTicks?]) {
        self.snapshots = snapshots
    }

    func readCPUTicks() -> HostCPUTicks? {
        guard !snapshots.isEmpty else { return nil }
        return snapshots.removeFirst()
    }
}

private struct StubMemoryUsageReader: HostMemoryUsageReading {
    let snapshot: UsageSnapshot?

    func readMemoryUsage() -> UsageSnapshot? {
        snapshot
    }
}
