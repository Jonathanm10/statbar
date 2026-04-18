import Foundation
import Testing
@testable import MenuBarStatsFeature

struct StatsRefreshCoordinatorTests {
    @MainActor
    @Test func startUsesClosedCadenceAndSkipsClosedProcessPolling() async {
        let viewModel = MenuBarViewModel()
        viewModel.apply(settings: FeatureSettings(
            refreshPreset: .balanced,
            menuBarDisplayFormat: .cpuPercent,
            processCount: .five,
            showsPID: true,
            showsDiskStats: false
        ))
        let scheduler = FakeScheduler()
        let hostReader = StubHostStatisticsReader(snapshot: HostSummarySnapshot(cpuUsage: .loading, memoryUsage: UsageSnapshot(usedBytes: 10, totalBytes: 20)))
        let diskProvider = StubDiskUsageProvider(snapshot: UsageSnapshot(usedBytes: 5, totalBytes: 10))
        let processProvider = StubProcessListProvider()
        let subject = StatsRefreshCoordinator(
            viewModel: viewModel,
            hostStatisticsReader: hostReader,
            diskUsageProvider: diskProvider,
            processListProvider: processProvider,
            scheduler: scheduler,
            configuration: .v1
        )

        subject.start()
        await Task.yield()

        #expect(processProvider.refreshCallCount == 0)
        #expect(scheduler.activeIntervals.sorted() == [3])
        #expect(viewModel.cpuUsage == .loading)
        #expect(viewModel.diskUsage == nil)
    }

    @MainActor
    @Test func openingPopoverRefreshesProcessesImmediatelyAndUsesOpenCadence() async {
        let viewModel = MenuBarViewModel()
        let scheduler = FakeScheduler()
        let processProvider = StubProcessListProvider(
            cpuRows: [ProcessRow(pid: 7, name: "Sample", metric: .percent(12))],
            memoryRows: [ProcessRow(pid: 8, name: "Memory", metric: .bytes(2048))]
        )
        let subject = StatsRefreshCoordinator(
            viewModel: viewModel,
            hostStatisticsReader: StubHostStatisticsReader(snapshot: HostSummarySnapshot(cpuUsage: .loading, memoryUsage: nil)),
            diskUsageProvider: StubDiskUsageProvider(snapshot: nil),
            processListProvider: processProvider,
            scheduler: scheduler,
            configuration: .v1
        )

        subject.start()
        subject.setPopoverPresented(true)
        await Task.yield()

        #expect(processProvider.refreshCallCount == 1)
        #expect(viewModel.topCPUProcesses.count == 1)
        #expect(viewModel.topMemoryProcesses.count == 1)
        #expect(scheduler.activeIntervals.sorted() == [2, 2, 30])

        subject.setPopoverPresented(false)
        #expect(scheduler.activeIntervals.sorted() == [3, 30])
    }

    @MainActor
    @Test func applyingSettingsUpdatesCadenceAndProcessLimit() async {
        let viewModel = MenuBarViewModel()
        let scheduler = FakeScheduler()
        let processProvider = StubProcessListProvider()
        let subject = StatsRefreshCoordinator(
            viewModel: viewModel,
            hostStatisticsReader: StubHostStatisticsReader(snapshot: HostSummarySnapshot(cpuUsage: .loading, memoryUsage: nil)),
            diskUsageProvider: StubDiskUsageProvider(snapshot: nil),
            processListProvider: processProvider,
            scheduler: scheduler,
            configuration: .v1
        )

        subject.start()
        subject.setPopoverPresented(true)
        subject.apply(
            settings: FeatureSettings(
                refreshPreset: .frequent,
                menuBarDisplayFormat: .iconOnly,
                processCount: .ten,
                showsPID: true,
                showsDiskStats: true
            )
        )
        await Task.yield()

        #expect(scheduler.activeIntervals.sorted() == [1, 1, 15])
    }

    @MainActor
    @Test func applyingSettingsDisablesAndReenablesDiskPolling() async {
        let viewModel = MenuBarViewModel()
        let scheduler = FakeScheduler()
        let diskProvider = StubDiskUsageProvider(snapshot: UsageSnapshot(usedBytes: 5, totalBytes: 10))
        let subject = StatsRefreshCoordinator(
            viewModel: viewModel,
            hostStatisticsReader: StubHostStatisticsReader(snapshot: HostSummarySnapshot(cpuUsage: .loading, memoryUsage: nil)),
            diskUsageProvider: diskProvider,
            processListProvider: StubProcessListProvider(),
            scheduler: scheduler,
            configuration: .v1
        )

        subject.start()
        await Task.yield()
        #expect(scheduler.activeIntervals.contains(30))
        #expect(diskProvider.readCallCount == 1)

        subject.apply(settings: FeatureSettings(
            refreshPreset: .balanced,
            menuBarDisplayFormat: .cpuPercent,
            processCount: .five,
            showsPID: true,
            showsDiskStats: false
        ))
        await Task.yield()
        #expect(scheduler.activeIntervals.contains(30) == false)
        #expect(viewModel.diskUsage == nil)

        subject.apply(settings: FeatureSettings(
            refreshPreset: .balanced,
            menuBarDisplayFormat: .cpuPercent,
            processCount: .five,
            showsPID: true,
            showsDiskStats: true
        ))
        await Task.yield()
        #expect(scheduler.activeIntervals.contains(30))
        #expect(diskProvider.readCallCount == 2)
    }
}

private final class FakeScheduler: RepeatingScheduling {
    private final class TaskBox: ScheduledTask {
        let interval: TimeInterval
        var isCancelled = false

        init(interval: TimeInterval) {
            self.interval = interval
        }

        func cancel() {
            isCancelled = true
        }
    }

    private var tasks: [TaskBox] = []

    var activeIntervals: [TimeInterval] {
        tasks.filter { !$0.isCancelled }.map(\.interval)
    }

    func scheduleRepeating(every interval: TimeInterval, action: @escaping @Sendable () -> Void) -> ScheduledTask {
        let box = TaskBox(interval: interval)
        tasks.append(box)
        return box
    }
}

private struct StubHostStatisticsReader: HostStatisticsReading {
    let snapshot: HostSummarySnapshot

    func readHostSnapshot() -> HostSummarySnapshot {
        snapshot
    }
}

private final class StubDiskUsageProvider: DiskUsageProviding {
    let snapshot: UsageSnapshot?
    private(set) var readCallCount = 0

    init(snapshot: UsageSnapshot?) {
        self.snapshot = snapshot
    }

    func readDiskUsage() -> UsageSnapshot? {
        readCallCount += 1
        return snapshot
    }
}

private final class StubProcessListProvider: ProcessListProviding {
    private(set) var refreshCallCount = 0
    private let cpuRows: [ProcessRow]
    private let memoryRows: [ProcessRow]

    init(cpuRows: [ProcessRow] = [], memoryRows: [ProcessRow] = []) {
        self.cpuRows = cpuRows
        self.memoryRows = memoryRows
    }

    func topProcesses(limit: Int) -> ProcessLists {
        refreshCallCount += 1
        return ProcessLists(
            cpu: Array(cpuRows.prefix(limit)),
            memory: Array(memoryRows.prefix(limit))
        )
    }
}
