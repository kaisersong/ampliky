import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBar: MenuBarController?
    let configStore = ConfigStore()
    let contextMonitor = ContextMonitor()
    let jscRunner = JSCRunner()
    var ruleEngine: RuleEngine!
    var hotkeyTrigger: HotkeyTrigger!
    var socketServer: SocketServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up main menu with Edit menu (required for Cmd+V paste to work in LSUIElement app)
        let mainMenu = NSMenu(title: "Main Menu")
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu

        // Standard edit commands for paste support
        editMenu.addItem(withTitle: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu

        // Only create menubar if user hasn't chosen silent mode
        if configStore.shouldShowMenubar() {
            menuBar = MenuBarController()
            menuBar?.setup()
        }

        #if DEBUG
        // Reset permissions on every debug build so macOS doesn't get confused
        // by changing code signatures between builds
        PermissionChecker.resetAllPermissions()
        #endif

        let rules = configStore.loadRules()

        // Seed default teleport shortcuts on first launch
        if rules.isEmpty {
            seedDefaultShortcuts()
        }

        ruleEngine = RuleEngine(rules: configStore.loadRules())

        // Check and prompt for permissions
        PermissionChecker.checkAndPrompt()

        hotkeyTrigger = HotkeyTrigger()
        registerHotkeys(rules: configStore.loadRules())
        hotkeyTrigger.start()

        socketServer = SocketServer()
        socketServer.setHandler { [weak self] request in
            self?.handleRPC(request) ?? SocketProtocol.errorResponse(id: request.id, code: -32603, message: "Internal error")
        }
        try? socketServer.start()
    }

    private func registerHotkeys(rules: [Rule]) {
        for rule in rules {
            guard rule.enabled else { continue }
            if case .hotkey(let key) = rule.trigger {
                hotkeyTrigger.register(keySpec: key) { [weak self] in
                    self?.executeRule(rule)
                }
            }
        }
    }

    private func executeRule(_ rule: Rule) {
        // Visual feedback
        menuBar?.notifyShortcutFired(rule)

        guard let scriptPath = rule.scriptPath else {
            for action in rule.actions {
                executeFallbackAction(action)
            }
            return
        }
        let fullPath = configStore.scriptsDir.appendingPathComponent(scriptPath).path
        guard let script = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
            Logger.shared.log(level: .error, message: "找不到脚本: \(scriptPath)")
            menuBar?.notifyShortcutFired(rule)
            return
        }
        let result = jscRunner.execute(script: script)
        if !result.success, let error = result.error {
            print("[Ampliky] script error: \(error)")
            Logger.shared.log(level: .error, message: "脚本错误: \(error)")
        } else {
            Logger.shared.log(level: .info, message: "执行成功: \(rule.name)")
        }
    }

    private func executeFallbackAction(_ action: RuleAction) {
        switch action.name {
        case "teleportCursor":
            if let to = action.params["to"] { CursorAction.teleport(to: to) }
        case "launchApp":
            if let name = action.params["name"] { AppAction.launch(name: name) }
        case "quitApp":
            if let name = action.params["name"] { AppAction.quit(name: name) }
        default: break
        }
    }

    private func seedDefaultShortcuts() {
        let scriptStore = ScriptStore()

        // Single shortcut: ⌘⌥↑ 跳到另一个屏幕
        let script = "Ampliky.cursor.warpNext()"
        let file = scriptStore.saveScript(content: script, name: "跳到另一个屏幕")
        configStore.addRule(Rule(
            id: UUID().uuidString, name: "跳到另一个屏幕",
            trigger: .hotkey(key: "cmd+opt+up"),
            actions: [], enabled: true, source: "user", scriptPath: file
        ))

        Logger.shared.log(level: .info, message: "初始化默认快捷指令: 跳屏 ⌘⌥↑")
    }

    private func handleRPC(_ request: RPCRequest) -> Data {
        switch request.method {
        case "run":
            guard let script = request.params["script"] as? String else {
                return SocketProtocol.errorResponse(id: request.id, code: -32602, message: "missing 'script' field")
            }
            let result = jscRunner.execute(script: script)
            if result.success {
                return SocketProtocol.successResponse(id: request.id, result: ["success": true, "output": result.output ?? ""])
            } else {
                return SocketProtocol.errorResponse(id: request.id, code: -32000, message: result.error ?? "script failed")
            }
        case "rule.list":
            let rules = configStore.loadRules()
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(rules)) ?? Data()
            let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
            return SocketProtocol.successResponse(id: request.id, result: ["rules": arr])
        case "rule.remove":
            guard let id = request.params["id"] as? String else {
                return SocketProtocol.errorResponse(id: request.id, code: -32602, message: "missing rule id")
            }
            configStore.removeRule(id: id)
            return SocketProtocol.successResponse(id: request.id, result: ["removed": true])
        case "context":
            return SocketProtocol.successResponse(id: request.id, result: [
                "screens": NSScreen.screens.count,
            ])
        default:
            return SocketProtocol.errorResponse(id: request.id, code: -32601, message: "Method not found: \(request.method)")
        }
    }
}

private func appDelegateMain() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}

@main
enum AmplikyApp {
    static func main() {
        appDelegateMain()
    }
}
