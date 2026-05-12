import AppKit

class ContextMonitor {
    private(set) var screenCount: Int = NSScreen.screens.count
    var onScreenCountChanged: ((Int) -> Void)?

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        let newCount = NSScreen.screens.count
        if newCount != screenCount {
            screenCount = newCount
            onScreenCountChanged?(newCount)
        }
    }
}
