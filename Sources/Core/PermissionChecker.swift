import AppKit
import Carbon

enum PermissionChecker {

    static func hasInputMonitoringPermission() -> Bool {
        // Try to create an event tap - if it fails, we don't have permission
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                     options: .defaultTap, eventsOfInterest: mask,
                                     callback: { _, _, _, _ in nil }, userInfo: nil)
        if let tap = tap {
            CFMachPortInvalidate(tap)
            return true
        }
        return false
    }

    static func requestInputMonitoring() {
        // Attempt to create event tap to trigger system prompt
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        _ = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                               options: .defaultTap, eventsOfInterest: mask,
                               callback: { _, _, _, _ in nil }, userInfo: nil)
    }

    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    static func checkAndPrompt() {
        let needsInput = !hasInputMonitoringPermission()
        let needsAccess = !hasAccessibilityPermission()

        guard needsInput || needsAccess else {
            Logger.shared.log(level: .info, message: "权限检查通过，无需请求")
            return
        }

        var info = "Ampliky 需要以下权限来正常工作：\n"
        if needsInput { info += "• 输入监控 — 监听全局快捷键\n" }
        if needsAccess { info += "• 辅助功能 — 管理窗口位置" }

        Logger.shared.log(level: .info, message: "请求权限: \(info)")

        let alert = NSAlert()
        alert.messageText = "需要权限"
        alert.informativeText = info
        alert.addButton(withTitle: "去设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            if needsInput { requestInputMonitoring() }
            if needsAccess { requestAccessibilityPermission() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
}
