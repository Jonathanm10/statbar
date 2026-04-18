import AppKit
import Combine
import MenuBarStatsFeature
@testable import MenuBarStats

final class StubCoordinator: StatsRefreshCoordinating {
    private(set) var presentedStates: [Bool] = []
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func start() {
        startCallCount += 1
    }

    func setPopoverPresented(_ isPresented: Bool) {
        presentedStates.append(isPresented)
    }

    func stop() {
        stopCallCount += 1
    }
}

@MainActor
final class StubSettingsStore: SettingsStore {
    @Published var featureSettings: FeatureSettings = .default

    var featureSettingsPublisher: AnyPublisher<FeatureSettings, Never> {
        $featureSettings.eraseToAnyPublisher()
    }
}

@MainActor
final class StubLaunchAtLoginController: LaunchAtLoginControlling {
    @Published private(set) var state: LaunchAtLoginState = .notRegistered
    private(set) var setEnabledCalls: [Bool] = []

    var statePublisher: AnyPublisher<LaunchAtLoginState, Never> {
        $state.eraseToAnyPublisher()
    }

    func refreshState() {}

    func setEnabled(_ enabled: Bool) {
        setEnabledCalls.append(enabled)
        state = enabled ? .enabled : .notRegistered
    }
}

@MainActor
final class RecordingPreferencesPresenter: PreferencesPresenting {
    private(set) var showCallCount = 0

    func show() {
        showCallCount += 1
    }
}

@MainActor
final class RecordingStatusItemRenderer: StatusItemRendering {
    private(set) var renderCallCount = 0

    func render(button: NSStatusBarButton?, viewModel: MenuBarStatsFeature.MenuBarViewModel, settings: FeatureSettings) {
        renderCallCount += 1
    }
}
