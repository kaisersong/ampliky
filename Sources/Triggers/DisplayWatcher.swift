import AppKit

class DisplayWatcher {
    private var onChange: (([String]) -> Void)?
    private var knownDisplays: [String] = []

    init() {
        knownDisplays = getCurrentDisplayIDs()
    }

    func start(_ callback: @escaping ([String]) -> Void) {
        onChange = callback

        // Watch for display configuration changes
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.appleDisplaysDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkForChanges()
        }

        // Also watch NSScreen change notifications
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func checkForChanges() {
        let currentDisplays = getCurrentDisplayIDs()

        if currentDisplays.count != knownDisplays.count {
            // Display count changed
            if currentDisplays.count > knownDisplays.count {
                // Display added - find which one
                let newDisplays = currentDisplays.filter { !knownDisplays.contains($0) }
                for displayID in newDisplays {
                    onChange?([displayID])
                }
            }
            knownDisplays = currentDisplays
        }
    }

    private func getCurrentDisplayIDs() -> [String] {
        return NSScreen.screens.compactMap { screen in
            // Use the display number as identifier
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                return String(number.intValue)
            }
            return nil
        }
    }
}
