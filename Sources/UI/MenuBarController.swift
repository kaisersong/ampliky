import AppKit

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var nltWindow: NLTInputWindow?
    private var shortcutListWindow: ShortcutListWindow?
    private var llmConfigWindow: LLMConfigWindow?
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

        let titleItem = NSMenuItem(title: "⚡ Ampliky", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "✚ 新建快捷指令...", action: #selector(openNLT), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "📋 快捷指令列表", action: #selector(openShortcutList), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "🤖 LLM 配置", action: #selector(openLLMConfig), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "📝 运行日志", action: #selector(openLog), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let hideTitle = ConfigStore().shouldShowMenubar() ? "⚙ 隐藏图标" : "⚙ 显示图标"
        menu.addItem(NSMenuItem(title: hideTitle, action: #selector(toggleMenubar), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "退出 Ampliky", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
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

    @objc private func openLLMConfig() {
        if llmConfigWindow == nil { llmConfigWindow = LLMConfigWindow(); llmConfigWindow?.delegate = self }
        llmConfigWindow?.makeKeyAndOrderFront(nil)
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
        if !current {
            let alert = NSAlert()
            alert.messageText = "菜单图标已隐藏"
            alert.informativeText = "快捷指令仍然正常工作。如需重新显示图标，请运行:\nmkdir -p ~/.ampliky && echo '{\"showMenubar\":true}' > ~/.ampliky/prefs.json\n然后重启 Ampliky。"
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}

extension MenuBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === nltWindow { nltWindow = nil }
        if window === shortcutListWindow { shortcutListWindow = nil }
        if window === llmConfigWindow { llmConfigWindow = nil }
        if window === logWindow { logWindow = nil }
    }
}
