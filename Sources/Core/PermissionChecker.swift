import AppKit
import Carbon

enum PermissionChecker {

    // Check if we have Input Monitoring permission by trying to create an event tap
    static func hasInputMonitoringPermission() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, _, _ in nil },
            userInfo: nil
        )
        if let tap = tap {
            CFMachPortInvalidate(tap)
            return true
        }
        return false
    }

    // Request Input Monitoring permission by trying to create an event tap.
    // If the app is not in TCC, macOS will automatically add it and prompt the user.
    static func requestInputMonitoringPermission() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        _ = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, _, _ in nil },
            userInfo: nil
        )
        Logger.shared.log(level: .debug, message: "已尝试注册输入监控权限")
    }

    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    static func checkAndPrompt() {
        let needsInput = !hasInputMonitoringPermission()
        let needsAccess = !hasAccessibilityPermission()

        guard needsInput || needsAccess else {
            Logger.shared.log(level: .info, message: "权限检查通过")
            return
        }

        // Request Input Monitoring FIRST by creating an event tap
        // This registers the app in TCC and may trigger a system prompt
        if needsInput {
            requestInputMonitoringPermission()
            // Give macOS a moment to process the registration
            Thread.sleep(forTimeInterval: 0.5)
        }

        var info = "Ampliky 需要以下权限：\n"
        if needsInput { info += "• 输入监控 — 监听全局快捷键\n" }
        if needsAccess { info += "• 辅助功能 — 管理窗口位置" }
        info += "\n请在系统设置中勾选 Ampliky。"

        Logger.shared.log(level: .info, message: "请求权限")

        let alert = NSAlert()
        alert.messageText = "需要权限"
        alert.informativeText = info
        alert.addButton(withTitle: "去设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            if needsAccess { requestAccessibilityPermission() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // Ensure the app is registered in TCC database so it appears in System Settings.
    static func ensureRegisteredInTCC() {
        // Try to create an event tap - this registers the app in TCC
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        _ = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, _, _ in nil },
            userInfo: nil
        )
        Logger.shared.log(level: .debug, message: "已请求注册到输入监控列表")
    }
}
