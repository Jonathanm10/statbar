import Combine
import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginState: Equatable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
    case error

    var isEnabled: Bool {
        if case .enabled = self { return true }
        return false
    }

    var detailText: String? {
        switch self {
        case .enabled:
            nil
        case .notRegistered:
            "The app is not registered to launch at login."
        case .requiresApproval:
            "macOS requires approval in System Settings > Login Items."
        case .notFound:
            "The login item could not be found."
        case .error:
            "macOS could not update the launch-at-login setting."
        }
    }
}

@MainActor
protocol LaunchAtLoginControlling: AnyObject {
    var state: LaunchAtLoginState { get }
    var statePublisher: AnyPublisher<LaunchAtLoginState, Never> { get }
    func refreshState()
    func setEnabled(_ enabled: Bool)
}

@MainActor
final class SMAppServiceLaunchAtLoginController: ObservableObject, LaunchAtLoginControlling {
    @Published private(set) var state: LaunchAtLoginState

    init() {
        state = Self.mapStatus(SMAppService.mainApp.status)
    }

    var statePublisher: AnyPublisher<LaunchAtLoginState, Never> {
        $state.eraseToAnyPublisher()
    }

    func refreshState() {
        state = Self.mapStatus(SMAppService.mainApp.status)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshState()
        } catch {
            state = .error
        }
    }

    private static func mapStatus(_ status: SMAppService.Status) -> LaunchAtLoginState {
        switch status {
        case .enabled:
            .enabled
        case .notRegistered:
            .notRegistered
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .notFound
        @unknown default:
            .error
        }
    }
}
