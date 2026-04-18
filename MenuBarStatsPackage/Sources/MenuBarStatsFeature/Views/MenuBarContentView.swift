import SwiftUI

public struct MenuBarContentView: View {
    @ObservedObject private var viewModel: MenuBarViewModel
    @State private var processTab: ProcessTab = .cpu
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    private enum ProcessTab: String, CaseIterable, Identifiable {
        case cpu = "CPU"
        case memory = "Memory"
        var id: String { rawValue }
    }

    public init(
        viewModel: MenuBarViewModel,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    metricCard(
                        icon: "cpu",
                        title: "CPU",
                        value: viewModel.cpuDisplayText,
                        detail: "Total usage",
                        fraction: cpuFraction,
                        style: .cpu
                    )
                    metricCard(
                        icon: "memorychip",
                        title: "Memory",
                        value: StatsFormatting.percentText(for: viewModel.memoryUsage),
                        detail: StatsFormatting.usageDetailText(for: viewModel.memoryUsage),
                        fraction: viewModel.memoryUsage?.fractionUsed ?? 0,
                        style: .memory
                    )
                    if viewModel.showsDiskSection {
                        metricCard(
                            icon: "internaldrive",
                            title: "Disk",
                            value: StatsFormatting.percentText(for: viewModel.diskUsage),
                            detail: StatsFormatting.usageDetailText(for: viewModel.diskUsage),
                            fraction: viewModel.diskUsage?.fractionUsed ?? 0,
                            style: .disk
                        )
                    }
                    processCard
                }
                .padding(16)
            }

            Divider()

            HStack {
                Button(action: onOpenSettings) {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Quit", action: onQuit)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("q")
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 380)
    }

    // MARK: - Helpers

    private var cpuFraction: Double {
        if case let .value(val) = viewModel.cpuUsage { return val / 100 }
        return 0
    }

    // MARK: - Metric Card

    private func metricCard(
        icon: String,
        title: String,
        value: String,
        detail: String,
        fraction: Double,
        style: MetricStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(style.accent)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.title3.weight(.semibold).monospacedDigit())
            }

            GradientBar(fraction: fraction, style: style)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Process Card

    private var processCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Processes")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $processTab) {
                    ForEach(ProcessTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            let rows = processTab == .cpu
                ? viewModel.visibleCPUProcesses
                : viewModel.visibleMemoryProcesses
            let style: MetricStyle = processTab == .cpu ? .cpu : .memory

            if rows.isEmpty {
                Text("No process data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        processRow(row, allRows: rows, style: style)
                    }
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
    }

    private func processRow(
        _ row: ProcessRow,
        allRows: [ProcessRow],
        style: MetricStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                if viewModel.showsPID {
                    Text("\(row.pid)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.quaternary)
                }
                Text(StatsFormatting.metricText(for: row.metric))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GradientBar(
                fraction: relativeFraction(row, in: allRows),
                style: style,
                height: 3
            )
        }
    }

    private func relativeFraction(_ row: ProcessRow, in rows: [ProcessRow]) -> Double {
        guard let leader = rows.first else { return 0 }
        switch (row.metric, leader.metric) {
        case let (.percent(val), .percent(maxVal)):
            return maxVal > 0 ? val / maxVal : 0
        case let (.bytes(val), .bytes(maxVal)):
            return maxVal > 0 ? Double(val) / Double(maxVal) : 0
        default:
            return 0
        }
    }
}

// MARK: - Gradient Bar

private struct GradientBar: View {
    let fraction: Double
    let style: MetricStyle
    var height: CGFloat = 6

    private var clamped: Double { min(max(fraction, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                Capsule()
                    .fill(style.gradient)
                    .frame(width: max(geo.size.width * clamped, clamped > 0 ? height : 0))
                    .shadow(color: style.accent.opacity(0.3), radius: 3, y: 1)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: clamped)
    }
}

// MARK: - Metric Style

private enum MetricStyle {
    case cpu, memory, disk

    var gradient: LinearGradient {
        switch self {
        case .cpu:
            LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        case .memory:
            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
        case .disk:
            LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        }
    }

    var accent: Color {
        switch self {
        case .cpu: .blue
        case .memory: .purple
        case .disk: .orange
        }
    }
}
