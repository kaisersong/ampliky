import AppKit

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var settingsWindow: SettingsWindow?
    private var nltWindow: NLTInputWindow?
    private var shortcutListWindow: ShortcutListWindow?
    private var logWindow: LogWindow?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.horizontal", accessibilityDescription: "Ampliky")
            button.image?.isTemplate = true
        }
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        addItem(menu, "新建快捷指令", #selector(openNLT))
        addItem(menu, "快捷指令列表", #selector(openShortcutList))
        addItem(menu, "运行日志", #selector(openLog))
        menu.addItem(NSMenuItem.separator())

        // Settings
        addItem(menu, "设置", #selector(openSettings))
        menu.addItem(NSMenuItem.separator())

        // Hide/show with shortcut
        let hideTitle = ConfigStore().shouldShowMenubar() ? "隐藏图标" : "显示图标"
        let hideItem = NSMenuItem(title: hideTitle, action: #selector(toggleMenubar), keyEquivalent: "h")
        hideItem.keyEquivalentModifierMask = [.command, .option, .control]
        hideItem.target = self
        menu.addItem(hideItem)

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
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
            settingsWindow?.delegate = self
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openNLT() {
        if nltWindow == nil { nltWindow = NLTInputWindow(); nltWindow?.delegate = self }
        nltWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openShortcutList() {
        if shortcutListWindow == nil { shortcutListWindow = ShortcutListWindow(); shortcutListWindow?.delegate = self }
        shortcutListWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openLog() {
        if logWindow == nil { logWindow = LogWindow(); logWindow?.delegate = self }
        logWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleMenubar() {
        let store = ConfigStore()
        let current = store.shouldShowMenubar()
        store.setShowMenubar(!current)
        Logger.shared.log(level: .info, message: "切换菜单图标: \(!current ? "显示" : "隐藏")")
        // Rebuild menu to update the item text
        buildMenu()
        if !current {
            let alert = NSAlert()
            alert.messageText = "图标已隐藏"
            alert.informativeText = "使用 ⌘⌥⌃H 可以重新显示图标。"
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
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
        if window === settingsWindow { settingsWindow = nil }
        if window === nltWindow { nltWindow = nil }
        if window === shortcutListWindow { shortcutListWindow = nil }
        if window === logWindow { logWindow = nil }
    }
}
