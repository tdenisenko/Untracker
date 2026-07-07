import Foundation

@MainActor
final class AppSettings {
    private enum Key {
        static let linkCleaningEnabled = "linkCleaningEnabled"
        static let selectedBrowserBundleIdentifier = "selectedBrowserBundleIdentifier"
        static let lastDefaultBrowserPromptVersion = "lastDefaultBrowserPromptVersion"
        static let startsAtLogin = "startsAtLogin"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.linkCleaningEnabled: true,
            Key.startsAtLogin: true
        ])
    }

    var isLinkCleaningEnabled: Bool {
        get { defaults.bool(forKey: Key.linkCleaningEnabled) }
        set { defaults.set(newValue, forKey: Key.linkCleaningEnabled) }
    }

    var selectedBrowserBundleIdentifier: String? {
        get { defaults.string(forKey: Key.selectedBrowserBundleIdentifier) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.selectedBrowserBundleIdentifier)
            } else {
                defaults.removeObject(forKey: Key.selectedBrowserBundleIdentifier)
            }
        }
    }

    var lastDefaultBrowserPromptVersion: String? {
        get { defaults.string(forKey: Key.lastDefaultBrowserPromptVersion) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.lastDefaultBrowserPromptVersion)
            } else {
                defaults.removeObject(forKey: Key.lastDefaultBrowserPromptVersion)
            }
        }
    }

    var startsAtLogin: Bool {
        get { defaults.bool(forKey: Key.startsAtLogin) }
        set { defaults.set(newValue, forKey: Key.startsAtLogin) }
    }
}
