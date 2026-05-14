import AppKit

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var settingsWindowController: SettingsWindowController?
    private var nltWindow: NLTInputWindow?
    private var shortcutListWindow: ShortcutListWindow?
    private var logWindow: LogWindow?
    private var debugLogWindow: LogViewerWindow?
    #if DEBUG
    private var debugOverlayEnabled = true
    #else
    private var debugOverlayEnabled = false
    #endif

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            // Load custom menubar icon
            let iconSize = NSSize(width: 18, height: 18)
            var menubarIcon: NSImage?

            // Try loading MenubarIcon from asset catalog (template mode already set in Contents.json)
            if let icon = NSImage(named: NSImage.Name("MenubarIcon")) {
                menubarIcon = icon
                print("[Ampliky] Loaded MenubarIcon from asset catalog")
            }

            // Try loading from bundle resources
            if menubarIcon == nil {
                let bundle = Bundle.main
                if let iconPath = bundle.path(forResource: "MenubarIcon", ofType: "png"),
                   let icon = NSImage(contentsOfFile: iconPath) {
                    menubarIcon = icon
                    menubarIcon?.isTemplate = true
                    print("[Ampliky] Loaded MenubarIcon from PNG resource")
                }
            }

            if let icon = menubarIcon {
                icon.size = iconSize
                button.image = icon
            } else {
                // Fallback to SF Symbol
                button.image = NSImage(systemSymbolName: "bolt.horizontal", accessibilityDescription: "Ampliky")
                button.image?.isTemplate = true
                print("[Ampliky] Using fallback SF Symbol")
            }
        }
        buildMenu()
        #if DEBUG
        if debugOverlayEnabled {
            DebugOverlayWindow.show()
        }
        #endif
    }

    private func buildMenu() {
        let menu = NSMenu()

        addItem(menu, "新建快捷指令", #selector(openNLT))
        addItem(menu, "快捷指令列表", #selector(openShortcutList))
        addItem(menu, "运行日志", #selector(openLog))
        menu.addItem(NSMenuItem.separator())

        addItem(menu, "设置", #selector(openSettings))
        menu.addItem(NSMenuItem.separator())

        // Hide/show menubar
        let hideTitle = ConfigStore().shouldShowMenubar() ? "隐藏图标" : "显示图标"
        let hideItem = NSMenuItem(title: hideTitle, action: #selector(toggleMenubar), keyEquivalent: "h")
        hideItem.keyEquivalentModifierMask = [.command, .option, .control]
        hideItem.target = self
        menu.addItem(hideItem)

        // Debug mode
        let debugTitle = debugOverlayEnabled ? "关闭调试模式" : "打开调试模式"
        let debugItem = NSMenuItem(title: debugTitle, action: #selector(toggleDebug), keyEquivalent: "")
        debugItem.target = self
        menu.addItem(debugItem)

        // Permission settings (debug only)
        #if DEBUG
        addItem(menu, "权限设置", #selector(openPermissionSettings))
        #endif

        // Log viewer
        addItem(menu, "日志查看器", #selector(openDebugLog))

        // About
        addItem(menu, "关于 Ampliky", #selector(showAbout))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.loadSettings()
    }

    @objc private func openNLT() {
        if nltWindow == nil {
            nltWindow = NLTInputWindow()
            nltWindow?.delegate = self
        }
        nltWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openShortcutList() {
        if shortcutListWindow == nil {
            shortcutListWindow = ShortcutListWindow()
            shortcutListWindow?.delegate = self
        } else {
            shortcutListWindow?.refresh()
        }
        shortcutListWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openLog() {
        if logWindow == nil { logWindow = LogWindow(); logWindow?.delegate = self }
        logWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openDebugLog() {
        if debugLogWindow == nil { debugLogWindow = LogViewerWindow() }
        debugLogWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    #if DEBUG
    @objc private func openPermissionSettings() {
        let alert = NSAlert()
        alert.messageText = "权限设置"
        alert.informativeText = "请在系统设置中勾选 Ampliky：\n\n1. 输入监控 — 监听快捷键\n2. 辅助功能 — 管理窗口\n\n如果列表中没有 Ampliky，请点击右下角 + 号手动添加。"
        alert.addButton(withTitle: "去设置")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    #endif

    @objc private func toggleMenubar() {
        let store = ConfigStore()
        let current = store.shouldShowMenubar()
        store.setShowMenubar(!current)
        Logger.shared.log(level: .info, message: "切换菜单图标")
        buildMenu()
        if !current {
            let alert = NSAlert()
            alert.messageText = "图标已隐藏"
            alert.informativeText = "使用快捷键可重新显示。"
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }

    @objc private func toggleDebug() {
        debugOverlayEnabled.toggle()
        if debugOverlayEnabled {
            DebugOverlayWindow.show()
            Logger.shared.log(level: .debug, message: "调试模式已开启")
            DebugOverlayWindow.flash("调试模式已开启")
        } else {
            DebugOverlayWindow.hide()
            Logger.shared.log(level: .debug, message: "调试模式已关闭")
        }
        buildMenu()
    }

    func notifyShortcutFired(_ rule: Rule) {
        let shortcut: String
        switch rule.trigger {
        case .hotkey(let key): shortcut = key
        default: shortcut = rule.name
        }
        ActionToast.show(action: rule.name, shortcut: shortcut)
        if debugOverlayEnabled {
            DebugOverlayWindow.flash("\(shortcut) -> \(rule.name)")
        }
        Logger.shared.log(level: .debug, message: "触发: \(shortcut) → \(rule.name)")
    }

    @objc private func showAbout() {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "0"

        let alert = NSAlert()
        alert.messageText = "Ampliky"
        alert.informativeText = "AI 快捷指令引擎\n版本 \(version) (\(build))\n\n用户说人话，LLM 生成脚本，本地高速执行。"
        alert.addButton(withTitle: "检查更新")
        alert.addButton(withTitle: "确定")

        if alert.runModal() == .alertFirstButtonReturn {
            checkForUpdates()
        }
    }

    private func checkForUpdates() {
        if let url = URL(string: "https://github.com/kaisersong/ampliky/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension MenuBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindowController?.window { settingsWindowController = nil }
        if window === nltWindow { nltWindow = nil }
        if window === shortcutListWindow { shortcutListWindow = nil }
        if window === logWindow { logWindow = nil }
        if window === debugLogWindow { debugLogWindow = nil }
    }
}

extension MenuBarController: NLTInputWindowDelegate {
    func nltInputWindowDidSave(_ window: NLTInputWindow) {
        // Open shortcut list after saving a new shortcut
        openShortcutList()
    }
}
