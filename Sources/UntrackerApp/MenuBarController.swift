import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private static let statusSymbolName = "link.badge.minus"

    private let settings: AppSettings
    private let browserRegistry: BrowserRegistry
    private let defaultBrowserManager: DefaultBrowserManager
    private let loginItemManager: LoginItemManager
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    private let statusMenuItem = NSMenuItem(title: "Untracker", action: nil, keyEquivalent: "")
    private lazy var linkCleaningMenuItem = NSMenuItem(
        title: "Clean Links",
        action: #selector(toggleLinkCleaning),
        keyEquivalent: ""
    )
    private let browserMenuItem = NSMenuItem(title: "Open Cleaned Links In", action: nil, keyEquivalent: "")
    private let browserMenu = NSMenu(title: "Open Cleaned Links In")
    private lazy var defaultBrowserMenuItem = NSMenuItem(
        title: "Set as Default Browser...",
        action: #selector(openDefaultBrowserSettings),
        keyEquivalent: ""
    )
    private lazy var startAtLoginMenuItem = NSMenuItem(
        title: "Start at Login",
        action: #selector(toggleStartAtLogin),
        keyEquivalent: ""
    )
    private lazy var quitMenuItem = NSMenuItem(
        title: "Quit Untracker",
        action: #selector(quit),
        keyEquivalent: "q"
    )

    init(
        settings: AppSettings,
        browserRegistry: BrowserRegistry,
        defaultBrowserManager: DefaultBrowserManager,
        loginItemManager: LoginItemManager
    ) {
        self.settings = settings
        self.browserRegistry = browserRegistry
        self.defaultBrowserManager = defaultBrowserManager
        self.loginItemManager = loginItemManager
        super.init()
    }

    func install() {
        configureStatusItem()
        configureMenu()
        update()
    }

    func menuWillOpen(_ menu: NSMenu) {
        update()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.imagePosition = .imageOnly
        button.toolTip = "Untracker"
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self

        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        linkCleaningMenuItem.target = self
        menu.addItem(linkCleaningMenuItem)

        browserMenuItem.submenu = browserMenu
        menu.addItem(browserMenuItem)

        defaultBrowserMenuItem.target = self
        menu.addItem(defaultBrowserMenuItem)

        startAtLoginMenuItem.target = self
        menu.addItem(startAtLoginMenuItem)

        menu.addItem(.separator())
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
    }

    private func update() {
        linkCleaningMenuItem.state = settings.isLinkCleaningEnabled ? .on : .off
        updateBrowserMenu()
        updateDefaultBrowserMenuItem()
        updateStartAtLoginMenuItem()
        updateStatusImage(color: settings.isLinkCleaningEnabled ? .systemGreen : .systemRed)

        if settings.isLinkCleaningEnabled {
            statusMenuItem.title = defaultBrowserManager.isUntrackerDefaultBrowser
                ? "Untracker: Link Cleaning Enabled"
                : "Untracker: Enabled (Not Default Browser)"
        } else {
            statusMenuItem.title = "Untracker: Link Cleaning Disabled"
        }
    }

    private func updateBrowserMenu() {
        browserMenu.removeAllItems()

        let browsers = browserRegistry.availableBrowsers()
        guard !browsers.isEmpty else {
            let item = NSMenuItem(title: "No Supported Browsers Found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            browserMenu.addItem(item)
            return
        }

        let selectedBrowser = browserRegistry.ensureSelectedBrowser()
        for browser in browsers {
            let item = NSMenuItem(
                title: browser.displayName,
                action: #selector(selectBrowser(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = browser.bundleIdentifier
            item.state = browser.bundleIdentifier == selectedBrowser?.bundleIdentifier ? .on : .off
            item.image = browserIcon(for: browser.applicationURL)
            browserMenu.addItem(item)
        }
    }

    private func browserIcon(for applicationURL: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: applicationURL.path).copy() as? NSImage ??
            NSWorkspace.shared.icon(forFile: applicationURL.path)
        icon.size = NSSize(width: 16, height: 16)
        icon.isTemplate = false
        return icon
    }

    private func updateDefaultBrowserMenuItem() {
        if defaultBrowserManager.isUntrackerDefaultBrowser {
            defaultBrowserMenuItem.title = "Default Browser: Untracker"
            defaultBrowserMenuItem.state = .on
        } else {
            defaultBrowserMenuItem.title = "Set as Default Browser..."
            defaultBrowserMenuItem.state = .off
        }
    }

    private func updateStartAtLoginMenuItem() {
        switch loginItemManager.status {
        case .enabled:
            startAtLoginMenuItem.title = "Start at Login"
            startAtLoginMenuItem.state = .on
            startAtLoginMenuItem.isEnabled = true
        case .disabled:
            startAtLoginMenuItem.title = "Start at Login"
            startAtLoginMenuItem.state = .off
            startAtLoginMenuItem.isEnabled = true
        case .requiresApproval:
            startAtLoginMenuItem.title = "Start at Login (Needs Approval)"
            startAtLoginMenuItem.state = .off
            startAtLoginMenuItem.isEnabled = true
        case .unavailable:
            startAtLoginMenuItem.title = "Start at Login (Unavailable)"
            startAtLoginMenuItem.state = .off
            startAtLoginMenuItem.isEnabled = false
        case .failed:
            startAtLoginMenuItem.title = "Start at Login"
            startAtLoginMenuItem.state = settings.startsAtLogin ? .on : .off
            startAtLoginMenuItem.isEnabled = true
        }
    }

    private func updateStatusImage(color: NSColor) {
        guard let button = statusItem.button else {
            return
        }

        button.contentTintColor = nil
        button.attributedTitle = NSAttributedString()
        if let image = Self.statusImage(color: color) {
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.attributedTitle = NSAttributedString(
                string: "U",
                attributes: [
                    .foregroundColor: color,
                    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
                ]
            )
        }
    }

    private static func statusImage(color: NSColor) -> NSImage? {
        guard
            let symbolImage = NSImage(
                systemSymbolName: statusSymbolName,
                accessibilityDescription: "Untracker"
            ),
            let configuredImage = symbolImage.withSymbolConfiguration(
                NSImage.SymbolConfiguration(paletteColors: [color])
            )
        else {
            return nil
        }

        configuredImage.isTemplate = false
        return configuredImage
    }

    @objc private func toggleLinkCleaning() {
        settings.isLinkCleaningEnabled.toggle()
        update()
    }

    @objc private func selectBrowser(_ sender: NSMenuItem) {
        guard let bundleIdentifier = sender.representedObject as? String else {
            return
        }

        guard let browser = browserRegistry
            .availableBrowsers()
            .first(where: { $0.bundleIdentifier == bundleIdentifier })
        else {
            return
        }

        browserRegistry.setSelectedBrowser(browser)
        update()
    }

    @objc private func openDefaultBrowserSettings() {
        defaultBrowserManager.openDefaultBrowserSettings()
        update()
    }

    @objc private func toggleStartAtLogin() {
        let status = loginItemManager.setStartsAtLogin(!settings.startsAtLogin)
        if case let .failed(message) = status {
            showLoginItemError(message)
        }
        update()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showLoginItemError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Start at Login could not be updated."
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
