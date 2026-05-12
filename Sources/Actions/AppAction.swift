import AppKit

enum AppAction {
    static func launch(name: String) {
        let ws = NSWorkspace.shared
        if let url = ws.urlForApplication(withBundleIdentifier: name) {
            ws.open(url)
            return
        }
        // Fallback: try by app name in /Applications
        ws.open(URL(fileURLWithPath: "/Applications/\(name).app"))
    }

    static func quit(name: String) {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.localizedName == name }
        for app in apps {
            app.terminate()
        }
    }
}
