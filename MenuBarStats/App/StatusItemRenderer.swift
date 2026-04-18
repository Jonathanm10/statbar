import AppKit
import MenuBarStatsFeature

@MainActor
protocol StatusItemRendering {
    func render(button: NSStatusBarButton?, viewModel: MenuBarStatsFeature.MenuBarViewModel, settings: FeatureSettings)
}

@MainActor
struct StatusItemRenderer: StatusItemRendering {
    func render(button: NSStatusBarButton?, viewModel: MenuBarStatsFeature.MenuBarViewModel, settings: FeatureSettings) {
        guard let button else { return }
        button.toolTip = "Menu Bar Stats"

        switch settings.menuBarDisplayFormat {
        case .iconOnly:
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: "Menu Bar Stats")
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly

        case .cpuPercent:
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: "Menu Bar Stats")
            button.title = " \(StatsFormatting.cpuUsageText(for: viewModel.cpuUsage))"
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageLeading

        case .cpuAndMemory:
            let text = viewModel.statusItemText ?? ""
            button.image = nil
            button.imagePosition = .noImage
            button.title = text
            button.attributedTitle = NSAttributedString(string: text)
        }
    }
}
