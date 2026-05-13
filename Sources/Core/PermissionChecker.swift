import AppKit
import Carbon

enum PermissionChecker {

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

        guard needsInput || needsAccess else { return }

        var info = "Ampliky 需要以下权限来正常工作：\n"
        if needsInput { info += "• 输入监控 — 监听全局快捷键\n" }
        if needsAccess { info += "• 辅助功能 — 管理窗口位置" }

        let alert = NSAlert()
        alert.messageText = "需要权限"
        alert.informativeText = info
        alert.addButton(withTitle: "去设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            // First request the one that can trigger system prompt
            if needsInput { requestInputMonitoring() }
            if needsAccess { requestAccessibilityPermission() }
            // Then open system settings as fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
}
