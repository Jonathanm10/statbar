import Foundation
import OSLog

private let performanceLog = OSLog(subsystem: "MenuBarStats", category: "Performance")

@discardableResult
private func withPerformanceSignpost<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
    let signpostID = OSSignpostID(log: performanceLog)
    os_signpost(.begin, log: performanceLog, name: name, signpostID: signpostID)
    defer { os_signpost(.end, log: performanceLog, name: name, signpostID: signpostID) }
    return try body()
}

@MainActor
public final class StatsRefreshCoordinator {
    private let viewModel: MenuBarViewModel
    private let hostStatisticsReader: HostStatisticsReading
    private let diskUsageProvider: DiskUsageProviding
    private let processListProvider: ProcessListProviding
    private let scheduler: RepeatingScheduling
    private var configuration: SamplingConfiguration

    private var summaryTask: ScheduledTask?
    private var diskTask: ScheduledTask?
    private var processTask: ScheduledTask?
    private var isStarted = false
    private var isPopoverPresented = false

    private var summaryRefreshInterval: TimeInterval {
        isPopoverPresented ? configuration.openSummaryInterval : configuration.closedSummaryInterval
    }

    public convenience init(viewModel: MenuBarViewModel) {
        self.init(
            viewModel: viewModel,
            hostStatisticsReader: HostStatisticsReader(),
            diskUsageProvider: DiskUsageProvider(),
            processListProvider: ProcessListProvider(),
            scheduler: RunLoopScheduler(),
            configuration: .v1
        )
    }

    public convenience init(viewModel: MenuBarViewModel, processListProvider: ProcessListProviding) {
        self.init(
            viewModel: viewModel,
            hostStatisticsReader: HostStatisticsReader(),
            diskUsageProvider: DiskUsageProvider(),
            processListProvider: processListProvider,
            scheduler: RunLoopScheduler(),
            configuration: .v1
        )
    }

    init(
        viewModel: MenuBarViewModel,
        hostStatisticsReader: HostStatisticsReading,
        diskUsageProvider: DiskUsageProviding,
        processListProvider: ProcessListProviding,
        scheduler: RepeatingScheduling,
        configuration: SamplingConfiguration
    ) {
        self.viewModel = viewModel
        self.hostStatisticsReader = hostStatisticsReader
        self.diskUsageProvider = diskUsageProvider
        self.processListProvider = processListProvider
        self.scheduler = scheduler
        self.configuration = configuration
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true

        refreshSummary()
        refreshDiskUsage()
        rescheduleSummaryTimer()
        scheduleDiskTimer()
    }

    public func setPopoverPresented(_ isPresented: Bool) {
        guard isStarted else { return }
        isPopoverPresented = isPresented

        rescheduleSummaryTimer()

        if isPresented {
            refreshSummary()
            refreshProcesses()
            scheduleProcessTimer()
        } else {
            processTask?.cancel()
            processTask = nil
        }
    }

    public func apply(settings: FeatureSettings) {
        configuration = settings.refreshPreset.samplingConfiguration(processCount: settings.processCount.count)
        viewModel.apply(settings: settings)
        if !settings.showsDiskStats {
            viewModel.apply(diskUsage: nil)
        }

        guard isStarted else { return }

        rescheduleSummaryTimer()
        refreshSummary()
        scheduleDiskTimer()
        refreshDiskUsage()

        if isPopoverPresented {
            scheduleProcessTimer()
            refreshProcesses()
        }
    }

    public func stop() {
        summaryTask?.cancel()
        summaryTask = nil
        diskTask?.cancel()
        diskTask = nil
        processTask?.cancel()
        processTask = nil
        isStarted = false
    }

    private func scheduleSummaryTimer(every interval: TimeInterval) {
        summaryTask?.cancel()
        summaryTask = scheduler.scheduleRepeating(every: interval) { [weak self] in
            Task { @MainActor in
                self?.refreshSummary()
            }
        }
    }

    private func rescheduleSummaryTimer() {
        scheduleSummaryTimer(every: summaryRefreshInterval)
    }

    private func scheduleDiskTimer() {
        diskTask?.cancel()
        guard viewModel.showsDiskSection else {
            diskTask = nil
            return
        }

        diskTask = scheduler.scheduleRepeating(every: configuration.diskRefreshInterval) { [weak self] in
            Task { @MainActor in
                self?.refreshDiskUsage()
            }
        }
    }

    private func scheduleProcessTimer() {
        processTask?.cancel()
        processTask = scheduler.scheduleRepeating(every: configuration.openProcessInterval) { [weak self] in
            Task { @MainActor in
                self?.refreshProcesses()
            }
        }
    }

    private func refreshSummary() {
        withPerformanceSignpost("SummaryRefresh") {
            viewModel.apply(summary: hostStatisticsReader.readHostSnapshot())
        }
    }

    private func refreshDiskUsage() {
        guard viewModel.showsDiskSection else {
            viewModel.apply(diskUsage: nil)
            return
        }

        let diskUsage = withPerformanceSignpost("DiskRefresh") {
            diskUsageProvider.readDiskUsage()
        }
        viewModel.apply(diskUsage: diskUsage)
    }

    private func refreshProcesses() {
        let processLists = withPerformanceSignpost("TopProcessRefresh") {
            processListProvider.topProcesses(limit: configuration.topProcessCount)
        }

        viewModel.apply(cpuProcesses: processLists.cpu, memoryProcesses: processLists.memory)
    }
}
