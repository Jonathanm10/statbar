import Combine
import Foundation
import MenuBarStatsFeature

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var featureSettings: FeatureSettings
    @Published private(set) var launchAtLoginState: LaunchAtLoginState

    private let settingsStore: SettingsStore
    private let launchAtLoginController: LaunchAtLoginControlling
    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: SettingsStore, launchAtLoginController: LaunchAtLoginControlling) {
        self.settingsStore = settingsStore
        self.launchAtLoginController = launchAtLoginController
        featureSettings = settingsStore.featureSettings
        launchAtLoginState = launchAtLoginController.state

        settingsStore.featureSettingsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.featureSettings = settings
            }
            .store(in: &cancellables)

        launchAtLoginController.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.launchAtLoginState = state
            }
            .store(in: &cancellables)
    }

    func updateFeatureSettings(_ settings: FeatureSettings) {
        featureSettings = settings
        settingsStore.featureSettings = settings
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginController.setEnabled(enabled)
        launchAtLoginState = launchAtLoginController.state
    }
}
