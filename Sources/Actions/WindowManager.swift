import AppKit

enum WindowManager {

    // MARK: - Focused Window via Accessibility API

    static func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let window = focusedWindow as! AXUIElement? else { return nil }
        return window
    }

    static func windowScreen(_ window: AXUIElement) -> NSScreen? {
        var positionValue: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              let position = positionValue as! AXValue? else { return nil }

        var cgPoint = CGPoint.zero
        guard AXValueGetValue(position, .cgPoint, &cgPoint) else { return nil }

        // Find which screen contains this point
        return NSScreen.screens.first { screen in
            screen.frame.contains(cgPoint)
        }
    }

    static func windowSize(_ window: AXUIElement) -> CGSize? {
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let size = sizeValue as! AXValue? else { return nil }

        var cgSize = CGSize.zero
        guard AXValueGetValue(size, .cgSize, &cgSize) else { return nil }
        return cgSize
    }

    static func setWindowPosition(_ window: AXUIElement, point: CGPoint) -> Bool {
        var cgPoint = point
        guard let axValue = AXValueCreate(.cgPoint, &cgPoint) else { return false }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axValue) == .success
    }

    // MARK: - Move Window to Screen

    static func moveToNextScreen() -> Bool {
        guard let window = focusedWindow() else { return false }
        guard let currentScreen = windowScreen(window) else { return false }
        guard let windowSize = windowSize(window) else { return false }

        let screens = NSScreen.screens
        guard let currentIndex = screens.firstIndex(of: currentScreen) else { return false }
        let nextIndex = (currentIndex + 1) % screens.count
        let targetScreen = screens[nextIndex]

        return centerWindowOnScreen(window, size: windowSize, screen: targetScreen)
    }

    static func moveToPrevScreen() -> Bool {
        guard let window = focusedWindow() else { return false }
        guard let currentScreen = windowScreen(window) else { return false }
        guard let windowSize = windowSize(window) else { return false }

        let screens = NSScreen.screens
        guard let currentIndex = screens.firstIndex(of: currentScreen) else { return false }
        let prevIndex = (currentIndex - 1 + screens.count) % screens.count
        let targetScreen = screens[prevIndex]

        return centerWindowOnScreen(window, size: windowSize, screen: targetScreen)
    }

    static func moveToScreen(_ index: Int) -> Bool {
        guard let window = focusedWindow() else { return false }
        guard let windowSize = windowSize(window) else { return false }

        let screens = NSScreen.screens
        guard index >= 0 && index < screens.count else { return false }
        let targetScreen = screens[index]

        return centerWindowOnScreen(window, size: windowSize, screen: targetScreen)
    }

    // MARK: - Center Window on Screen

    static func centerWindowOnScreen(_ window: AXUIElement, size: CGSize, screen: NSScreen) -> Bool {
        let x = screen.frame.origin.x + (screen.frame.width - size.width) / 2
        let y = screen.frame.origin.y + (screen.frame.height - size.height) / 2
        let centerPoint = CGPoint(x: x, y: y)
        return setWindowPosition(window, point: centerPoint)
    }

    // MARK: - Window Half / Maximize (for focused window of any app)

    static func leftHalf() -> Bool {
        guard let window = focusedWindow() else { return false }
        guard let screen = windowScreen(window) else { return false }

        var newSize = CGSize(width: screen.frame.width / 2, height: screen.frame.height)
        var newPosition = CGPoint(x: screen.frame.origin.x, y: screen.frame.origin.y)

        let axSize = AXValueCreate(.cgSize, &newSize)!
        let axPos = AXValueCreate(.cgPoint, &newPosition)!

        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize) == .success &&
               AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPos) == .success
    }

    static func rightHalf() -> Bool {
        guard let window = focusedWindow() else { return false }
        guard let screen = windowScreen(window) else { return false }

        var newSize = CGSize(width: screen.frame.width / 2, height: screen.frame.height)
        var newPosition = CGPoint(x: screen.frame.origin.x + screen.frame.width / 2, y: screen.frame.origin.y)

        let axSize = AXValueCreate(.cgSize, &newSize)!
        let axPos = AXValueCreate(.cgPoint, &newPosition)!

        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize) == .success &&
               AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPos) == .success
    }

    static func maximize() -> Bool {
        guard let window = focusedWindow() else { return false }
        guard let screen = windowScreen(window) else { return false }

        var newSize = CGSize(width: screen.frame.width, height: screen.frame.height)
        var newPosition = CGPoint(x: screen.frame.origin.x, y: screen.frame.origin.y)

        let axSize = AXValueCreate(.cgSize, &newSize)!
        let axPos = AXValueCreate(.cgPoint, &newPosition)!

        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize) == .success &&
               AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPos) == .success
    }
}
