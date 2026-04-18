import Foundation

public enum StatsFormatting {
    public static func cpuUsageText(for usage: CPUUsageState) -> String {
        switch usage {
        case .loading:
            return "Loading…"
        case let .value(value):
            return format(percentage: value)
        }
    }

    public static func usageText(for usage: UsageSnapshot?) -> String {
        guard let usage else { return "Unavailable" }
        return "\(format(bytes: usage.usedBytes)) / \(format(bytes: usage.totalBytes)) (\(format(percentage: usage.fractionUsed * 100)))"
    }

    public static func metricText(for metric: ProcessRow.Metric) -> String {
        switch metric {
        case let .percent(value):
            return format(percentage: value)
        case let .bytes(value):
            return format(bytes: value)
        }
    }

    public static func statusItemText(
        cpuUsage: CPUUsageState,
        memoryUsage: UsageSnapshot?,
        format: MenuBarDisplayFormat
    ) -> String? {
        switch format {
        case .iconOnly:
            return nil
        case .cpuPercent:
            return cpuUsageText(for: cpuUsage)
        case .cpuAndMemory:
            let cpuPct = compactCpuText(for: cpuUsage)
            let memPct = compactMemoryText(for: memoryUsage)
            return "\(cpuPct)  \(memPct)"
        }
    }

    public static func compactMemoryUsageText(for usage: UsageSnapshot?) -> String {
        guard let usage else { return "MEM —" }
        return format(bytes: usage.usedBytes)
    }

    public static func miniBar(fraction: Double, segments: Int = 6) -> String {
        let clamped = min(max(fraction, 0), 1)
        let filled = Int(round(clamped * Double(segments)))
        let empty = segments - filled
        return String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
    }

    public static func compactCpuText(for usage: CPUUsageState) -> String {
        switch usage {
        case .loading:
            return "CPU —"
        case let .value(value):
            return "CPU \(wholePercentText(for: value))"
        }
    }

    public static func compactMemoryText(for usage: UsageSnapshot?) -> String {
        guard let usage else { return "MEM —" }
        return "MEM \(gigabytesText(for: usage.usedBytes))"
    }

    public static func cpuValueText(for usage: CPUUsageState) -> String {
        switch usage {
        case .loading:
            return "—"
        case let .value(value):
            return wholePercentText(for: value)
        }
    }

    public static func memoryValueText(for usage: UsageSnapshot?) -> String {
        guard let usage else { return "—" }
        return gigabytesText(for: usage.usedBytes)
    }

    public static func percentText(for usage: UsageSnapshot?) -> String {
        guard let usage else { return "—" }
        return format(percentage: usage.fractionUsed * 100)
    }

    public static func usageDetailText(for usage: UsageSnapshot?) -> String {
        guard let usage else { return "Unavailable" }
        return "\(format(bytes: usage.usedBytes)) of \(format(bytes: usage.totalBytes))"
    }

    public static func format(percentage: Double) -> String {
        String(format: "%.1f%%", percentage.isFinite ? percentage : 0)
    }

    public static func format(bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }

    private static func wholePercentText(for value: Double) -> String {
        String(format: "%.0f%%", value.isFinite ? value : 0)
    }

    private static func gigabytesText(for bytes: UInt64) -> String {
        let gigabytes = Double(bytes) / (1024 * 1024 * 1024)
        if gigabytes >= 10 {
            return String(format: "%.0fG", gigabytes)
        }
        return String(format: "%.1fG", gigabytes)
    }
}
