import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager {
    enum LoginItemStatus: Equatable {
        case disabled
        case enabled
        case requiresApproval
        case unavailable
        case failed(String)
    }

    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    var status: LoginItemStatus {
        serviceStatus()
    }

    func registerIfNeeded() {
        guard settings.startsAtLogin else {
            return
        }
        _ = setStartsAtLogin(true, reportingErrors: false)
    }

    @discardableResult
    func setStartsAtLogin(_ enabled: Bool, reportingErrors: Bool = true) -> LoginItemStatus {
        settings.startsAtLogin = enabled

        guard #available(macOS 13.0, *) else {
            return .unavailable
        }

        do {
            let service = SMAppService.mainApp
            if enabled {
                switch service.status {
                case .enabled:
                    return .enabled
                case .requiresApproval:
                    return .requiresApproval
                default:
                    try service.register()
                    return serviceStatus()
                }
            } else {
                if service.status != .notRegistered {
                    try service.unregister()
                }
                return serviceStatus()
            }
        } catch {
            return reportingErrors ? .failed(error.localizedDescription) : serviceStatus()
        }
    }

    private func serviceStatus() -> LoginItemStatus {
        guard #available(macOS 13.0, *) else {
            return .unavailable
        }

        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }
}
