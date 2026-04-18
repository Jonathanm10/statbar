import AppKit
import XCTest
import MenuBarStatsFeature
@testable import MenuBarStats

@MainActor
final class StatusItemRendererTests: XCTestCase {
    func testIconOnlyFormatLeavesStatusItemTitleEmpty() {
        let renderer = StatusItemRenderer()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let viewModel = MenuBarStatsFeature.MenuBarViewModel()
        viewModel.apply(summary: HostSummarySnapshot(cpuUsage: .value(12.3), memoryUsage: UsageSnapshot(usedBytes: 1_024, totalBytes: 2_048)))
        var settings = FeatureSettings.default
        settings.menuBarDisplayFormat = .iconOnly

        renderer.render(button: statusItem.button, viewModel: viewModel, settings: settings)

        XCTAssertEqual(statusItem.button?.title, "")
        XCTAssertEqual(statusItem.button?.imagePosition, .imageOnly)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testCPUAndMemoryFormatRendersPlainText() {
        let renderer = StatusItemRenderer()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let viewModel = MenuBarStatsFeature.MenuBarViewModel()
        viewModel.apply(summary: HostSummarySnapshot(cpuUsage: .value(12.3), memoryUsage: UsageSnapshot(usedBytes: 512 * 1024 * 1024, totalBytes: 1024 * 1024 * 1024)))
        var settings = FeatureSettings.default
        settings.menuBarDisplayFormat = .cpuAndMemory

        renderer.render(button: statusItem.button, viewModel: viewModel, settings: settings)

        let text = statusItem.button?.title ?? ""
        XCTAssertTrue(text.contains("CPU 12%"), "Expected CPU value")
        XCTAssertTrue(text.contains("MEM 0.5G"), "Expected memory value")
        XCTAssertEqual(statusItem.button?.imagePosition, .noImage)
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
