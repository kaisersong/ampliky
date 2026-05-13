import AppKit
import Carbon

enum PermissionChecker {

    // Attempt to register the app in macOS Input Monitoring list.
    // This must be called early so the app appears in System Settings.
    // After tccutil reset, macOS removes the app from the list entirely
    // until it attempts to create an event tap.
    static func registerForInputMonitoring() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        _ = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, _, _ in nil },
            userInfo: nil
        )
        // Keep the tap alive briefly so macOS registers the app
        // Then invalidate it — the permission check will re-check below
    }

    static func hasInputMonitoringPermission() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
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

    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    static func checkAndPrompt() {
        // Always register first so the app appears in System Settings
        // This is critical after tccutil reset (which removes the app from the list)
        registerForInputMonitoring()

        let needsInput = !hasInputMonitoringPermission()
        let needsAccess = !hasAccessibilityPermission()

        guard needsInput || needsAccess else {
            Logger.shared.log(level: .info, message: "权限检查通过")
            return
        }

        var info = "Ampliky 需要以下权限来正常工作：\n"
        if needsInput { info += "• 输入监控 — 监听全局快捷键\n" }
        if needsAccess { info += "• 辅助功能 — 管理窗口位置" }

        info += "\n如果设置中没有看到 Ampliky，请先勾选其他应用再回来刷新列表。"

        Logger.shared.log(level: .info, message: "请求权限")

        let alert = NSAlert()
        alert.messageText = "需要权限"
        alert.informativeText = info
        alert.addButton(withTitle: "去设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            if needsAccess { requestAccessibilityPermission() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
}
