import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBar = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar.setup()
    }
}
