import XCTest
import MenuBarStatsFeature
@testable import MenuBarStats

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testFeatureSettingsPersistAcrossStoreInstances() {
        let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let subject = UserDefaultsSettingsStore(userDefaults: userDefaults)
        subject.featureSettings = FeatureSettings(
            refreshPreset: .frequent,
            menuBarDisplayFormat: .cpuAndMemory,
            processCount: .ten,
            showsPID: false,
            showsDiskStats: false
        )

        let reloaded = UserDefaultsSettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.featureSettings, subject.featureSettings)
    }
}
