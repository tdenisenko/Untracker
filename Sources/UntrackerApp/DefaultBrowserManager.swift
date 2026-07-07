import AppKit
import CoreServices

@MainActor
final class DefaultBrowserManager {
    private let settings: AppSettings
    private let ownBundleIdentifier: String

    init(
        settings: AppSettings,
        ownBundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.tdenisenko.Untracker"
    ) {
        self.settings = settings
        self.ownBundleIdentifier = ownBundleIdentifier
    }

    var isUntrackerDefaultBrowser: Bool {
        Self.defaultBrowserBundleIdentifier(for: "http") == ownBundleIdentifier &&
            Self.defaultBrowserBundleIdentifier(for: "https") == ownBundleIdentifier
    }

    func registerAsBrowserCandidate() {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
        NSWorkspace.shared.noteFileSystemChanged(Bundle.main.bundlePath)
    }

    static func defaultBrowserBundleIdentifier(for scheme: String) -> String? {
        guard
            let sampleURL = URL(string: "\(scheme)://example.com"),
            let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: sampleURL)
        else {
            return nil
        }

        return Bundle(url: applicationURL)?.bundleIdentifier
    }

    func promptForDefaultBrowserIfNeeded() {
        registerAsBrowserCandidate()

        guard !isUntrackerDefaultBrowser else {
            return
        }

        let promptVersion = Self.promptVersion
        guard settings.lastDefaultBrowserPromptVersion != promptVersion else {
            return
        }

        settings.lastDefaultBrowserPromptVersion = promptVersion

        let alert = NSAlert()
        alert.messageText = "Make Untracker the default browser?"
        alert.informativeText = "Untracker needs to be the default browser to clean links opened from other apps. It will forward cleaned links to your selected browser."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openDefaultBrowserSettings()
        }
    }

    func openDefaultBrowserSettings() {
        let settingsURLs = [
            URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension"),
            URL(string: "x-apple.systempreferences:com.apple.preference.general")
        ].compactMap { $0 }

        for settingsURL in settingsURLs where NSWorkspace.shared.open(settingsURL) {
            return
        }

        if let systemSettingsURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences"
        ) {
            NSWorkspace.shared.open(systemSettingsURL)
        }
    }

    private static var promptVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return "\(shortVersion)-\(build)"
    }
}
