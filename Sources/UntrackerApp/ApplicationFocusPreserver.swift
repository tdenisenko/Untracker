import AppKit

@MainActor
final class ApplicationFocusPreserver {
    private let workspace: NSWorkspace
    private let ownProcessIdentifier: pid_t
    private var lastExternalApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    init(
        workspace: NSWorkspace = .shared,
        ownProcessIdentifier: pid_t = ProcessInfo.processInfo.processIdentifier
    ) {
        self.workspace = workspace
        self.ownProcessIdentifier = ownProcessIdentifier

        if let frontmostApplication = workspace.frontmostApplication,
           frontmostApplication.processIdentifier != ownProcessIdentifier {
            lastExternalApplication = frontmostApplication
        }

        activationObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else {
                return
            }

            Task { @MainActor in
                self?.recordActivation(of: application)
            }
        }
    }

    deinit {
        if let activationObserver {
            workspace.notificationCenter.removeObserver(activationObserver)
        }
    }

    func restorePreviousApplicationIfNeeded() {
        guard NSApp.isActive else {
            return
        }

        guard let application = lastExternalApplication, !application.isTerminated else {
            NSApp.deactivate()
            return
        }

        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: application)
            application.activate()
        } else {
            NSApp.deactivate()
            application.activate(options: [])
        }
    }

    private func recordActivation(of application: NSRunningApplication) {
        guard application.processIdentifier != ownProcessIdentifier else {
            return
        }

        lastExternalApplication = application
    }
}
