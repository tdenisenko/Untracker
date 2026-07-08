import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private var hasFinishedLaunching = false
    private var pendingURLs: [URL] = []
    private lazy var loginItemManager = LoginItemManager(settings: settings)
    private lazy var browserRegistry = BrowserRegistry(settings: settings)
    private lazy var defaultBrowserManager = DefaultBrowserManager(settings: settings)
    private lazy var linkRouter = LinkRouter(
        settings: settings,
        browserRegistry: browserRegistry
    )
    private lazy var menuBarController = MenuBarController(
        settings: settings,
        browserRegistry: browserRegistry,
        defaultBrowserManager: defaultBrowserManager,
        loginItemManager: loginItemManager
    )

    func applicationWillFinishLaunching(_ notification: Notification) {
        registerURLHandler()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        NSApp.setActivationPolicy(.accessory)
        loginItemManager.registerIfNeeded()
        defaultBrowserManager.registerAsBrowserCandidate()
        browserRegistry.ensureSelectedBrowser()
        menuBarController.install()
        hasFinishedLaunching = true
        flushPendingURLs()
        defaultBrowserManager.promptForDefaultBrowserIfNeeded()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Untracker")
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Untracker",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func registerURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return
        }

        routeWhenReady(url)
    }

    private func routeWhenReady(_ url: URL) {
        if hasFinishedLaunching {
            linkRouter.route(url)
        } else {
            pendingURLs.append(url)
        }
    }

    private func flushPendingURLs() {
        let urls = pendingURLs
        pendingURLs.removeAll()
        urls.forEach { linkRouter.route($0) }
    }
}
