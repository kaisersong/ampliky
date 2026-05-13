import AppKit
import Carbon

enum PermissionChecker {

    // MARK: - Input Monitoring (for CGEvent tap)

    static func hasInputMonitoringPermission() -> Bool {
        guard let sym = dlsym(dlopen(nil, RTLD_NOW), "CGPreflightListenEventAccess") else { return true }
        typealias Fn = @convention(c) () -> Bool
        return unsafeBitCast(sym, to: Fn.self)()
    }

    static func requestInputMonitoring() {
        guard let sym = dlsym(dlopen(nil, RTLD_NOW), "CGRequestListenEventAccess") else { return }
        typealias Fn = @convention(c) () -> Void
        unsafeBitCast(sym, to: Fn.self)()
    }

    // MARK: - Accessibility (for window management)

    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Combined check

    static func checkAndPrompt() {
        if !hasInputMonitoringPermission() {
            let alert = NSAlert()
            alert.messageText = "需要输入监控权限"
            alert.informativeText = "Ampliky 需要输入监控权限来监听全局快捷键。请点击「去设置」前往系统设置授权。"
            alert.addButton(withTitle: "去设置")
            alert.addButton(withTitle: "稍后")
            if alert.runModal() == .alertFirstButtonReturn {
                openSystemSettings()
            }
        }

        if !hasAccessibilityPermission() {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "Ampliky 需要辅助功能权限来管理窗口。请点击「去设置」前往系统设置授权。"
            alert.addButton(withTitle: "去设置")
            alert.addButton(withTitle: "稍后")
            if alert.runModal() == .alertFirstButtonReturn {
                openSystemSettings()
            }
        }
    }

    private static func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
