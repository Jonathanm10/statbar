import Combine
import Foundation
import MenuBarStatsFeature

@MainActor
protocol SettingsStore: AnyObject {
    var featureSettings: FeatureSettings { get set }
    var featureSettingsPublisher: AnyPublisher<FeatureSettings, Never> { get }
}

@MainActor
final class UserDefaultsSettingsStore: ObservableObject, SettingsStore {
    private enum Keys {
        static let featureSettings = "featureSettings"
    }

    private let userDefaults: UserDefaults
    @Published var featureSettings: FeatureSettings {
        didSet { persist() }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if
            let data = userDefaults.data(forKey: Keys.featureSettings),
            let decoded = try? JSONDecoder().decode(FeatureSettings.self, from: data)
        {
            featureSettings = decoded
        } else {
            featureSettings = .default
        }
    }

    var featureSettingsPublisher: AnyPublisher<FeatureSettings, Never> {
        $featureSettings.eraseToAnyPublisher()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(featureSettings) else { return }
        userDefaults.set(data, forKey: Keys.featureSettings)
    }
}
