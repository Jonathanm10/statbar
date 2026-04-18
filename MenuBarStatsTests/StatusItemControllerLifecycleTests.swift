import AppKit
import XCTest
import MenuBarStatsFeature
@testable import MenuBarStats

@MainActor
private final class FakePopoverPresenter: PopoverPresenting {
    var isShown = false
    var onDidClose: (() -> Void)?
    private(set) var showCallCount = 0
    private(set) var closeCallCount = 0

    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        isShown = true
        showCallCount += 1
    }

    func close() {
        guard isShown else { return }
        isShown = false
        closeCallCount += 1
        onDidClose?()
    }
}

@MainActor
final class StatusItemControllerLifecycleTests: XCTestCase {
    func testShowDismissReopenAndQuitLifecycle() {
        let coordinator = StubCoordinator()
        let popover = FakePopoverPresenter()
        let preferencesPresenter = RecordingPreferencesPresenter()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let viewModel = MenuBarStatsFeature.MenuBarViewModel()
        var quitCallCount = 0
        let controller = StatusItemController(
            viewModel: viewModel,
            coordinator: coordinator,
            preferencesPresenter: preferencesPresenter,
            popoverPresenter: popover,
            quitAction: { quitCallCount += 1 },
            statusItem: statusItem
        )

        controller.togglePopover(nil as AnyObject?)
        XCTAssertEqual(popover.showCallCount, 1)
        XCTAssertEqual(coordinator.presentedStates, [true])

        controller.togglePopover(nil as AnyObject?)
        XCTAssertEqual(popover.closeCallCount, 1)
        XCTAssertEqual(coordinator.presentedStates, [true, false])

        controller.togglePopover(nil as AnyObject?)
        XCTAssertEqual(popover.showCallCount, 2)
        XCTAssertEqual(coordinator.presentedStates, [true, false, true])

        controller.quit()
        XCTAssertEqual(coordinator.stopCallCount, 1)
        XCTAssertEqual(quitCallCount, 1)

        controller.openSettings()
        XCTAssertEqual(preferencesPresenter.showCallCount, 1)

        XCTAssertEqual(statusItem.button?.toolTip, "Menu Bar Stats")

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testDisplayFormatChangesUpdateStatusItemLive() {
        let coordinator = StubCoordinator()
        let popover = FakePopoverPresenter()
        let preferencesPresenter = RecordingPreferencesPresenter()
        let renderer = RecordingStatusItemRenderer()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let settingsStore = StubSettingsStore()
        settingsStore.featureSettings = FeatureSettings(
            refreshPreset: .balanced,
            menuBarDisplayFormat: .iconOnly,
            processCount: .five,
            showsPID: true,
            showsDiskStats: true
        )
        let viewModel = MenuBarStatsFeature.MenuBarViewModel()
        viewModel.apply(summary: HostSummarySnapshot(
            cpuUsage: .value(12.3),
            memoryUsage: UsageSnapshot(usedBytes: 512 * 1024 * 1024, totalBytes: 1024 * 1024 * 1024)
        ))

        let controller = StatusItemController(
            viewModel: viewModel,
            coordinator: coordinator,
            settingsStore: settingsStore,
            preferencesPresenter: preferencesPresenter,
            statusItemRenderer: renderer,
            popoverPresenter: popover,
            statusItem: statusItem
        )

        XCTAssertEqual(renderer.renderCallCount, 1)

        var settings = settingsStore.featureSettings
        settings.menuBarDisplayFormat = .cpuAndMemory
        settingsStore.featureSettings = settings
        viewModel.apply(settings: settings)
        viewModel.apply(summary: HostSummarySnapshot(
            cpuUsage: .value(13.3),
            memoryUsage: UsageSnapshot(usedBytes: 640 * 1024 * 1024, totalBytes: 1024 * 1024 * 1024)
        ))
        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline, renderer.renderCallCount < 2 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertEqual(renderer.renderCallCount, 2)
        _ = controller

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testProcessListOnlyChangesDoNotTriggerStatusItemRerender() {
        let coordinator = StubCoordinator()
        let popover = FakePopoverPresenter()
        let preferencesPresenter = RecordingPreferencesPresenter()
        let renderer = RecordingStatusItemRenderer()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let settingsStore = StubSettingsStore()
        settingsStore.featureSettings = FeatureSettings(
            refreshPreset: .balanced,
            menuBarDisplayFormat: .cpuPercent,
            processCount: .five,
            showsPID: true,
            showsDiskStats: true
        )
        let viewModel = MenuBarStatsFeature.MenuBarViewModel()
        viewModel.apply(settings: settingsStore.featureSettings)
        viewModel.apply(summary: HostSummarySnapshot(
            cpuUsage: .value(12.3),
            memoryUsage: UsageSnapshot(usedBytes: 512 * 1024 * 1024, totalBytes: 1024 * 1024 * 1024)
        ))

        let controller = StatusItemController(
            viewModel: viewModel,
            coordinator: coordinator,
            settingsStore: settingsStore,
            preferencesPresenter: preferencesPresenter,
            statusItemRenderer: renderer,
            popoverPresenter: popover,
            statusItem: statusItem
        )

        XCTAssertEqual(renderer.renderCallCount, 1)

        viewModel.apply(
            cpuProcesses: [ProcessRow(pid: 1, name: "A", metric: .percent(22))],
            memoryProcesses: [ProcessRow(pid: 1, name: "A", metric: .bytes(1024))]
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(renderer.renderCallCount, 1)

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testSummaryChangesTriggerStatusItemRerender() {
        let coordinator = StubCoordinator()
        let popover = FakePopoverPresenter()
        let preferencesPresenter = RecordingPreferencesPresenter()
        let renderer = RecordingStatusItemRenderer()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let settingsStore = StubSettingsStore()
        settingsStore.featureSettings = FeatureSettings(
            refreshPreset: .balanced,
            menuBarDisplayFormat: .cpuPercent,
            processCount: .five,
            showsPID: true,
            showsDiskStats: true
        )
        let viewModel = MenuBarStatsFeature.MenuBarViewModel()
        viewModel.apply(settings: settingsStore.featureSettings)
        viewModel.apply(summary: HostSummarySnapshot(
            cpuUsage: .value(12.3),
            memoryUsage: UsageSnapshot(usedBytes: 512 * 1024 * 1024, totalBytes: 1024 * 1024 * 1024)
        ))

        let controller = StatusItemController(
            viewModel: viewModel,
            coordinator: coordinator,
            settingsStore: settingsStore,
            preferencesPresenter: preferencesPresenter,
            statusItemRenderer: renderer,
            popoverPresenter: popover,
            statusItem: statusItem
        )

        XCTAssertEqual(renderer.renderCallCount, 1)

        viewModel.apply(summary: HostSummarySnapshot(
            cpuUsage: .value(44.4),
            memoryUsage: UsageSnapshot(usedBytes: 768 * 1024 * 1024, totalBytes: 1024 * 1024 * 1024)
        ))
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(renderer.renderCallCount, 2)
        _ = controller

        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
