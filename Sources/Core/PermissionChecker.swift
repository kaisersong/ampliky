import AppKit
import Carbon

enum PermissionChecker {
    // RTLD_DEFAULT for dlsym
    private static let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)

    // Check if we have Input Monitoring permission
    static func hasInputMonitoringPermission() -> Bool {
        do {
            guard let handle = dlopen(nil, RTLD_NOW),
                  let sym = dlsym(handle, "CGPreflightListenEventAccess") else {
                return false
            }
            dlclose(handle)
            typealias Fn = @convention(c) () -> Bool
            return unsafeBitCast(sym, to: Fn.self)()
        } catch {
            Logger.shared.log(level: .error, message: "检查输入监控权限失败: \(error.localizedDescription)")
            return false
        }
    }

    // Request Input Monitoring permission - shows system prompt and registers in TCC
    static func requestInputMonitoringPermission() {
        do {
            guard let handle = dlopen(nil, RTLD_NOW),
                  let sym = dlsym(handle, "CGRequestListenEventAccess") else {
                Logger.shared.log(level: .error, message: "无法找到 CGRequestListenEventAccess")
                return
            }
            dlclose(handle)
            typealias Fn = @convention(c) () -> Void
            unsafeBitCast(sym, to: Fn.self)()
        } catch {
            Logger.shared.log(level: .error, message: "请求输入监控权限失败: \(error.localizedDescription)")
        }
    }

    static func hasAccessibilityPermission() -> Bool {
        do {
            return AXIsProcessTrusted()
        } catch {
            Logger.shared.log(level: .error, message: "检查辅助功能权限失败: \(error.localizedDescription)")
            return false
        }
    }

    static func requestAccessibilityPermission() {
        do {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
        } catch {
            Logger.shared.log(level: .error, message: "请求辅助功能权限失败: \(error.localizedDescription)")
        }
    }

    static func checkAndPrompt() {
        do {
            let needsInput = !hasInputMonitoringPermission()
            let needsAccess = !hasAccessibilityPermission()

            guard needsInput || needsAccess else {
                Logger.shared.log(level: .info, message: "权限检查通过")
                return
            }

            var info = "Ampliky 需要以下权限：\n"
            if needsInput { info += "• 输入监控 — 监听全局快捷键\n" }
            if needsAccess { info += "• 辅助功能 — 管理窗口位置" }

            Logger.shared.log(level: .info, message: "请求权限")

            let alert = NSAlert()
            alert.messageText = "需要权限"
            alert.informativeText = info
            alert.addButton(withTitle: "去设置")
            alert.addButton(withTitle: "稍后")

            if alert.runModal() == .alertFirstButtonReturn {
                // Request Input Monitoring permission (this registers the app in TCC)
                if needsInput { requestInputMonitoringPermission() }
                if needsAccess { requestAccessibilityPermission() }
                // Open System Settings after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } catch {
            Logger.shared.log(level: .error, message: "权限检查失败: \(error.localizedDescription)")
        }
    }
}
