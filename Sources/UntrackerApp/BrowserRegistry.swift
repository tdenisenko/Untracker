import AppKit

struct DetectedBrowser: Equatable {
    let bundleIdentifier: String
    let displayName: String
    let applicationURL: URL
}

@MainActor
final class BrowserRegistry {
    private let settings: AppSettings
    private let ownBundleIdentifier: String

    init(
        settings: AppSettings,
        ownBundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.tdenisenko.Untracker"
    ) {
        self.settings = settings
        self.ownBundleIdentifier = ownBundleIdentifier
    }

    func availableBrowsers() -> [DetectedBrowser] {
        var seenApplicationPaths = Set<String>()
        var seenBundleIdentifiers = Set<String>()

        return candidateApplicationURLs().compactMap { applicationURL in
            let path = applicationURL.standardizedFileURL.path
            guard seenApplicationPaths.insert(path).inserted else {
                return nil
            }

            guard
                let bundle = Bundle(url: applicationURL),
                let bundleIdentifier = bundle.bundleIdentifier,
                bundleIdentifier != ownBundleIdentifier,
                seenBundleIdentifiers.insert(bundleIdentifier).inserted,
                isBrowser(bundle: bundle)
            else {
                return nil
            }

            return DetectedBrowser(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName(for: bundle, fallback: applicationURL.deletingPathExtension().lastPathComponent),
                applicationURL: applicationURL
            )
        }.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func selectedBrowser() -> DetectedBrowser? {
        guard let bundleIdentifier = settings.selectedBrowserBundleIdentifier else {
            return nil
        }

        return availableBrowsers().first { $0.bundleIdentifier == bundleIdentifier }
    }

    @discardableResult
    func ensureSelectedBrowser() -> DetectedBrowser? {
        if let selectedBrowser = selectedBrowser() {
            return selectedBrowser
        }

        let browsers = availableBrowsers()
        let defaultBrowserBundleIdentifier = DefaultBrowserManager.defaultBrowserBundleIdentifier(for: "https")
        let browser = browsers.first { $0.bundleIdentifier == defaultBrowserBundleIdentifier } ?? browsers.first

        settings.selectedBrowserBundleIdentifier = browser?.bundleIdentifier
        return browser
    }

    func setSelectedBrowser(_ browser: DetectedBrowser) {
        settings.selectedBrowserBundleIdentifier = browser.bundleIdentifier
    }

    private func candidateApplicationURLs() -> [URL] {
        webHandlerURLs() + installedApplicationURLs()
    }

    private func webHandlerURLs() -> [URL] {
        [
            URL(string: "https://example.com"),
            URL(string: "http://example.com")
        ]
        .compactMap { $0 }
        .flatMap { NSWorkspace.shared.urlsForApplications(toOpen: $0) }
    }

    private func installedApplicationURLs() -> [URL] {
        applicationDirectoryURLs().flatMap { applicationDirectoryURL -> [URL] in
            guard let enumerator = FileManager.default.enumerator(
                at: applicationDirectoryURL,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }

            return enumerator.compactMap { item -> URL? in
                guard let url = item as? URL, url.pathExtension == "app" else {
                    return nil
                }

                enumerator.skipDescendants()
                return url
            }
        }
    }

    private func applicationDirectoryURLs() -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "\(NSHomeDirectory())/Applications", isDirectory: true)
        ]
    }

    private func isBrowser(bundle: Bundle) -> Bool {
        hasWebURLScheme(bundle: bundle) && supportsWebBrowsingActivity(bundle: bundle)
    }

    private func hasWebURLScheme(bundle: Bundle) -> Bool {
        guard let urlTypes = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }

        let supportedSchemes = Set(
            urlTypes
                .compactMap { $0["CFBundleURLSchemes"] as? [String] }
                .flatMap { $0 }
                .map { $0.lowercased() }
        )

        return supportedSchemes.contains("http") || supportedSchemes.contains("https")
    }

    private func supportsWebBrowsingActivity(bundle: Bundle) -> Bool {
        let activityTypes = bundle.object(forInfoDictionaryKey: "NSUserActivityTypes") as? [String] ?? []
        return activityTypes.contains("NSUserActivityTypeBrowsingWeb")
    }

    private func displayName(for bundle: Bundle, fallback: String) -> String {
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
            fallback
    }
}
