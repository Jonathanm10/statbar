import AppKit
import Combine
import OSLog
import SwiftUI
import MenuBarStatsFeature

private let statusItemPerformanceLog = OSLog(subsystem: "MenuBarStats", category: "Performance")

@MainActor
protocol StatsRefreshCoordinating: AnyObject {
    func start()
    func setPopoverPresented(_ isPresented: Bool)
    func stop()
}

extension MenuBarStatsFeature.StatsRefreshCoordinator: StatsRefreshCoordinating {}

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popoverPresenter: PopoverPresenting
    private let coordinator: StatsRefreshCoordinating
    private let settingsStore: SettingsStore
    private let preferencesPresenter: PreferencesPresenting
    private let statusItemRenderer: StatusItemRendering
    private let quitAction: () -> Void
    private let viewModel: MenuBarStatsFeature.MenuBarViewModel
    private var cancellables = Set<AnyCancellable>()
    private var pendingRender: DispatchWorkItem?
    private var lastRenderState: MenuBarStatsFeature.MenuBarViewModel.StatusItemContent?

    private var currentSettings: FeatureSettings {
        settingsStore.featureSettings
    }

    init(
        viewModel: MenuBarStatsFeature.MenuBarViewModel,
        coordinator: StatsRefreshCoordinating,
        settingsStore: SettingsStore? = nil,
        preferencesPresenter: PreferencesPresenting? = nil,
        statusItemRenderer: StatusItemRendering? = nil,
        popoverPresenter: PopoverPresenting? = nil,
        quitAction: (() -> Void)? = nil,
        statusItem: NSStatusItem? = nil
    ) {
        let resolvedQuitAction = quitAction ?? { NSApplication.shared.terminate(nil) }
        let resolvedSettingsStore = settingsStore ?? UserDefaultsSettingsStore()
        let resolvedPreferencesPresenter = preferencesPresenter ?? NoopPreferencesPresenter()
        self.coordinator = coordinator
        self.viewModel = viewModel
        self.settingsStore = resolvedSettingsStore
        self.preferencesPresenter = resolvedPreferencesPresenter
        self.statusItemRenderer = statusItemRenderer ?? StatusItemRenderer()
        self.quitAction = resolvedQuitAction
        self.statusItem = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popoverPresenter = popoverPresenter ?? AppKitPopoverPresenter(
            rootView: AnyView(
                MenuBarStatsFeature.MenuBarContentView(
                    viewModel: viewModel,
                    onOpenSettings: {
                        resolvedPreferencesPresenter.show()
                    },
                    onQuit: { [weak coordinator] in
                        coordinator?.stop()
                        resolvedQuitAction()
                    }
                )
            ),
            contentSize: NSSize(width: 380, height: 520)
        )
        super.init()
        viewModel.apply(settings: resolvedSettingsStore.featureSettings)
        configureStatusItem()
        configurePopoverLifecycle()
        configureObservers()
    }

    convenience init(
        viewModel: MenuBarStatsFeature.MenuBarViewModel,
        coordinator: MenuBarStatsFeature.StatsRefreshCoordinator
    ) {
        self.init(viewModel: viewModel, coordinator: coordinator as StatsRefreshCoordinating)
    }

    convenience init(
        coordinator: StatsRefreshCoordinating,
        popoverPresenter: PopoverPresenting,
        quitAction: @escaping () -> Void,
        statusItem: NSStatusItem
    ) {
        self.init(
            viewModel: MenuBarStatsFeature.MenuBarViewModel(),
            coordinator: coordinator,
            popoverPresenter: popoverPresenter,
            quitAction: quitAction,
            statusItem: statusItem
        )
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popoverPresenter.isShown {
            popoverPresenter.close()
            return
        }

        guard let button = statusItem.button else { return }
        popoverPresenter.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        coordinator.setPopoverPresented(true)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        renderStatusItem(button: button)
        lastRenderState = viewModel.statusItemContent
    }

    private func configurePopoverLifecycle() {
        popoverPresenter.onDidClose = { [weak coordinator] in
            coordinator?.setPopoverPresented(false)
        }
    }

    private func configureObservers() {
        settingsStore.featureSettingsPublisher
            .sink { [weak self] _ in self?.scheduleRender() }
            .store(in: &cancellables)

        viewModel.statusItemContentPublisher
            .sink { [weak self] _ in self?.scheduleRender() }
            .store(in: &cancellables)
    }

    private func scheduleRender() {
        let renderState = viewModel.statusItemContent
        guard renderState != lastRenderState else { return }

        pendingRender?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.withStatusItemRenderSignpost {
                self.renderStatusItem(button: self.statusItem.button)
            }
            self.lastRenderState = renderState
        }
        pendingRender = work
        DispatchQueue.main.async(execute: work)
    }

    private func renderStatusItem(button: NSStatusBarButton?) {
        statusItemRenderer.render(button: button, viewModel: viewModel, settings: currentSettings)
    }

    private func withStatusItemRenderSignpost(_ body: () -> Void) {
        let signpostID = OSSignpostID(log: statusItemPerformanceLog)
        os_signpost(.begin, log: statusItemPerformanceLog, name: "StatusItemRender", signpostID: signpostID)
        defer {
            os_signpost(.end, log: statusItemPerformanceLog, name: "StatusItemRender", signpostID: signpostID)
        }
        body()
    }

    func openSettings() {
        preferencesPresenter.show()
    }

    func quit() {
        coordinator.stop()
        quitAction()
    }
}
