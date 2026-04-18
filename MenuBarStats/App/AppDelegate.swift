import AppKit
import Combine
import MenuBarStatsFeature

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: MenuBarStatsFeature.MenuBarViewModel?
    private var coordinator: MenuBarStatsFeature.StatsRefreshCoordinator?
    private var statusItemController: StatusItemController?
    private var settingsStore: UserDefaultsSettingsStore?
    private var launchAtLoginController: SMAppServiceLaunchAtLoginController?
    private var preferencesViewModel: PreferencesViewModel?
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let settingsStore = UserDefaultsSettingsStore()
        let launchAtLoginController = SMAppServiceLaunchAtLoginController()
        let viewModel = MenuBarStatsFeature.MenuBarViewModel()
        let processListProvider = MenuBarStatsFeature.ProcessListProvider(
            privilegedFetcher: HelperXPCClient()
        )
        let coordinator = MenuBarStatsFeature.StatsRefreshCoordinator(
            viewModel: viewModel,
            processListProvider: processListProvider
        )
        let preferencesViewModel = PreferencesViewModel(
            settingsStore: settingsStore,
            launchAtLoginController: launchAtLoginController
        )
        let preferencesPresenter = AppKitPreferencesPresenter(viewModel: preferencesViewModel)

        self.viewModel = viewModel
        self.coordinator = coordinator
        self.settingsStore = settingsStore
        self.launchAtLoginController = launchAtLoginController
        self.preferencesViewModel = preferencesViewModel

        viewModel.apply(settings: settingsStore.featureSettings)
        coordinator.apply(settings: settingsStore.featureSettings)

        settingsStore.featureSettingsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak viewModel, weak coordinator] settings in
                viewModel?.apply(settings: settings)
                coordinator?.apply(settings: settings)
            }
            .store(in: &cancellables)

        coordinator.start()
        statusItemController = StatusItemController(
            viewModel: viewModel,
            coordinator: coordinator,
            settingsStore: settingsStore,
            preferencesPresenter: preferencesPresenter
        )
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }
}
