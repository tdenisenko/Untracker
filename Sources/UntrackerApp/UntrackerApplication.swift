import AppKit

@main
enum UntrackerApplication {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()

        app.delegate = delegate
        app.run()
    }
}
