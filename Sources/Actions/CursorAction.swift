import Foundation
import CoreGraphics
import AppKit

struct ScreenInfo {
    let id: Int
    let frame: CGRect
}

enum CursorAction {

    static func resolveScreen(target: String, from currentIndex: Int, screens: [ScreenInfo]) -> Int? {
        switch target {
        case "next_screen":
            guard screens.count > 1 else { return nil }
            return (currentIndex + 1) % screens.count
        case "prev_screen":
            guard screens.count > 1 else { return nil }
            return (currentIndex - 1 + screens.count) % screens.count
        case "center":
            return nil
        default:
            if target.hasPrefix("screen_"), let n = Int(target.dropFirst("screen_".count)) {
                let index = n - 1
                return (0..<screens.count).contains(index) ? index : nil
            }
            return nil
        }
    }

    static func teleport(to target: String) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let screenInfos = screens.enumerated().map { i, s in
            ScreenInfo(id: i, frame: s.frame)
        }

        let currentScreen = screens.firstIndex { screen in
            let mouseLoc = NSEvent.mouseLocation
            return screen.frame.contains(mouseLoc)
        } ?? 0

        guard let targetIndex = resolveScreen(target: target, from: currentScreen, screens: screenInfos) else {
            if target == "center" {
                moveToCenter(of: screens[currentScreen])
            }
            return
        }

        let targetScreen = screens[targetIndex]
        moveToCenter(of: targetScreen)
    }

    private static func moveToCenter(of screen: NSScreen) {
        let center = CGPoint(
            x: screen.frame.origin.x + screen.frame.width / 2,
            y: screen.frame.origin.y + screen.frame.height / 2
        )
        CGWarpMouseCursorPosition(center)
    }
}
