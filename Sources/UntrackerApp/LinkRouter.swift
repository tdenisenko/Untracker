import AppKit
import UntrackerCore

@MainActor
final class LinkRouter {
    private let settings: AppSettings
    private let browserRegistry: BrowserRegistry
    private let cleaner: URLCleaner

    init(
        settings: AppSettings,
        browserRegistry: BrowserRegistry,
        cleaner: URLCleaner = URLCleaner()
    ) {
        self.settings = settings
        self.browserRegistry = browserRegistry
        self.cleaner = cleaner
    }

    func route(_ url: URL) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let destinationURL = await self.destinationURL(for: url)
            self.openInSelectedBrowser(destinationURL)
        }
    }

    private func destinationURL(for url: URL) async -> URL {
        guard settings.isLinkCleaningEnabled else {
            return url
        }

        let text = url.absoluteString
        let cleanedText = await cleaner.clean(
            text,
            allowsRemoteRequests: URLCleaner.allowsRemoteRequests(for: text)
        )
        return URL(string: cleanedText) ?? url
    }

    private func openInSelectedBrowser(_ url: URL) {
        guard let browser = browserRegistry.ensureSelectedBrowser() else {
            showNoBrowserAlert()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(
            [url],
            withApplicationAt: browser.applicationURL,
            configuration: configuration
        ) { [weak self] _, error in
            guard let error else {
                return
            }

            Task { @MainActor in
                self?.showOpenError(error, browser: browser)
            }
        }
    }

    private func showNoBrowserAlert() {
        let alert = NSAlert()
        alert.messageText = "No browser is available."
        alert.informativeText = "Install a browser that supports web links, launch it once, then choose it from the Untracker menu."
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func showOpenError(_ error: Error, browser: DetectedBrowser) {
        let alert = NSAlert()
        alert.messageText = "Untracker could not open \(browser.displayName)."
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
