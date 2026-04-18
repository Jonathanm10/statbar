import Combine
import Foundation

@MainActor
public final class MenuBarViewModel: ObservableObject {
    public struct StatusItemContent: Equatable, Sendable {
        public let format: MenuBarDisplayFormat
        public let cpuText: String
        public let memoryText: String

        public init(format: MenuBarDisplayFormat, cpuText: String, memoryText: String) {
            self.format = format
            self.cpuText = cpuText
            self.memoryText = memoryText
        }
    }

    @Published public private(set) var cpuUsage: CPUUsageState = .loading
    @Published public private(set) var memoryUsage: UsageSnapshot?
    @Published public private(set) var diskUsage: UsageSnapshot?
    @Published public private(set) var topCPUProcesses: [ProcessRow] = []
    @Published public private(set) var topMemoryProcesses: [ProcessRow] = []
    @Published public private(set) var settings: FeatureSettings = .default

    public init() {}

    public var cpuDisplayText: String {
        StatsFormatting.cpuUsageText(for: cpuUsage)
    }

    public var memoryDisplayText: String {
        StatsFormatting.usageText(for: memoryUsage)
    }

    public var diskDisplayText: String {
        StatsFormatting.usageText(for: diskUsage)
    }

    public var statusItemText: String? {
        StatsFormatting.statusItemText(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            format: settings.menuBarDisplayFormat
        )
    }

    public var visibleCPUProcesses: [ProcessRow] {
        Array(topCPUProcesses.prefix(settings.processCount.count))
    }

    public var visibleMemoryProcesses: [ProcessRow] {
        Array(topMemoryProcesses.prefix(settings.processCount.count))
    }

    public var showsPID: Bool {
        settings.showsPID
    }

    public var showsDiskSection: Bool {
        settings.showsDiskStats
    }

    public var statusItemContent: StatusItemContent {
        StatusItemContent(
            format: settings.menuBarDisplayFormat,
            cpuText: StatsFormatting.cpuValueText(for: cpuUsage),
            memoryText: StatsFormatting.memoryValueText(for: memoryUsage)
        )
    }

    public var statusItemContentPublisher: AnyPublisher<StatusItemContent, Never> {
        Publishers.CombineLatest3($cpuUsage, $memoryUsage, $settings)
            .map { cpuUsage, memoryUsage, settings in
                StatusItemContent(
                    format: settings.menuBarDisplayFormat,
                    cpuText: StatsFormatting.cpuValueText(for: cpuUsage),
                    memoryText: StatsFormatting.memoryValueText(for: memoryUsage)
                )
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public func apply(summary: HostSummarySnapshot) {
        cpuUsage = summary.cpuUsage
        memoryUsage = summary.memoryUsage
    }

    public func apply(diskUsage: UsageSnapshot?) {
        self.diskUsage = diskUsage
    }

    public func apply(cpuProcesses: [ProcessRow], memoryProcesses: [ProcessRow]) {
        topCPUProcesses = cpuProcesses
        topMemoryProcesses = memoryProcesses
    }

    public func apply(settings: FeatureSettings) {
        self.settings = settings
    }
}
