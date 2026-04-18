import Foundation

public enum RefreshPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case light
    case balanced
    case frequent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .light: "Light"
        case .balanced: "Balanced"
        case .frequent: "Frequent"
        }
    }

    public func samplingConfiguration(processCount: Int) -> SamplingConfiguration {
        switch self {
        case .light:
            SamplingConfiguration(
                closedSummaryInterval: 6,
                openSummaryInterval: 4,
                openProcessInterval: 4,
                diskRefreshInterval: 60,
                topProcessCount: processCount
            )
        case .balanced:
            SamplingConfiguration(
                closedSummaryInterval: 3,
                openSummaryInterval: 2,
                openProcessInterval: 2,
                diskRefreshInterval: 30,
                topProcessCount: processCount
            )
        case .frequent:
            SamplingConfiguration(
                closedSummaryInterval: 2,
                openSummaryInterval: 1,
                openProcessInterval: 1,
                diskRefreshInterval: 15,
                topProcessCount: processCount
            )
        }
    }
}

public enum MenuBarDisplayFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case iconOnly
    case cpuPercent
    case cpuAndMemory

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .iconOnly: "Icon Only"
        case .cpuPercent: "CPU %"
        case .cpuAndMemory: "CPU + Memory"
        }
    }
}

public enum ProcessCountOption: Int, CaseIterable, Codable, Sendable, Identifiable {
    case three = 3
    case five = 5
    case ten = 10

    public var id: Int { rawValue }
    public var count: Int { rawValue }
    public var title: String { String(rawValue) }
}

public struct FeatureSettings: Codable, Equatable, Sendable {
    public var refreshPreset: RefreshPreset
    public var menuBarDisplayFormat: MenuBarDisplayFormat
    public var processCount: ProcessCountOption
    public var showsPID: Bool
    public var showsDiskStats: Bool

    public init(
        refreshPreset: RefreshPreset,
        menuBarDisplayFormat: MenuBarDisplayFormat,
        processCount: ProcessCountOption,
        showsPID: Bool,
        showsDiskStats: Bool
    ) {
        self.refreshPreset = refreshPreset
        self.menuBarDisplayFormat = menuBarDisplayFormat
        self.processCount = processCount
        self.showsPID = showsPID
        self.showsDiskStats = showsDiskStats
    }

    public static let `default` = FeatureSettings(
        refreshPreset: .balanced,
        menuBarDisplayFormat: .cpuAndMemory,
        processCount: .five,
        showsPID: true,
        showsDiskStats: true
    )
}
