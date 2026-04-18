import XCTest
import MenuBarStatsFeature
@testable import MenuBarStats

@MainActor
final class PreferencesViewModelTests: XCTestCase {
    func testUpdatesFeatureSettingsThroughStore() {
        let store = StubSettingsStore()
        let controller = StubLaunchAtLoginController()
        let subject = PreferencesViewModel(settingsStore: store, launchAtLoginController: controller)

        var updated = store.featureSettings
        updated.processCount = .ten
        updated.showsPID = false
        subject.updateFeatureSettings(updated)

        XCTAssertEqual(store.featureSettings.processCount, .ten)
        XCTAssertFalse(store.featureSettings.showsPID)
        XCTAssertEqual(subject.featureSettings.processCount, .ten)
    }

    func testLaunchAtLoginToggleDelegatesToController() {
        let store = StubSettingsStore()
        let controller = StubLaunchAtLoginController()
        let subject = PreferencesViewModel(settingsStore: store, launchAtLoginController: controller)

        subject.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(controller.setEnabledCalls, [true])
        XCTAssertEqual(subject.launchAtLoginState, .enabled)
    }
}
