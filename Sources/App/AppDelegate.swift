import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBar: MenuBarController?
    let configStore = ConfigStore()
    let contextMonitor = ContextMonitor()
    let jscRunner = JSCRunner()
    var ruleEngine: RuleEngine!
    var hotkeyTrigger: HotkeyTrigger!
    var gestureTrigger: GestureTrigger!
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
        // In debug builds, always try to register in TCC so the app appears in System Settings
        // Don't reset - just ensure the app is registered
        PermissionChecker.ensureRegisteredInTCC()
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

        // Set up gesture trigger for trackpad gestures
        gestureTrigger = GestureTrigger()
        registerGestures(rules: configStore.loadRules())
        gestureTrigger.start()

        socketServer = SocketServer()
        socketServer.setHandler { [weak self] request in
            self?.handleRPC(request) ?? SocketProtocol.errorResponse(id: request.id, code: -32603, message: "Internal error")
        }
        try? socketServer.start()

        // Listen for rule changes from UI
        NotificationCenter.default.addObserver(
            self, selector: #selector(rulesChanged),
            name: NSNotification.Name("AmplikyRulesChanged"), object: nil
        )
    }

    @objc private func rulesChanged() {
        print("[Ampliky] Rules changed, reloading...")
        Logger.shared.log(level: .info, message: "规则变更，重新加载")

        // Stop existing triggers
        hotkeyTrigger.stop()
        gestureTrigger.stop()

        // Reload rules and re-register
        let rules = configStore.loadRules()
        ruleEngine = RuleEngine(rules: rules)
        registerHotkeys(rules: rules)
        registerGestures(rules: rules)

        // Restart triggers
        hotkeyTrigger.start()
        gestureTrigger.start()

        Logger.shared.log(level: .info, message: "规则重新加载完成 (\(rules.count) 条)")
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

    private func registerGestures(rules: [Rule]) {
        for rule in rules {
            guard rule.enabled else { continue }
            switch rule.trigger {
            case .gesture(let fingers, let action):
                let gestureKey = gestureIdentifier(fingers: fingers, action: action)
                gestureTrigger.register(gesture: gestureKey) { [weak self] in
                    self?.executeRule(rule)
                }
                #if DEBUG
                print("[Ampliky] Registered gesture: \(gestureKey) -> \(rule.name)")
                #endif
            default:
                break
            }
        }
    }

    private func gestureIdentifier(fingers: Int, action: String) -> String {
        switch (fingers, action) {
        case (3, "tap"): return GestureTrigger.threeFingerTap
        case (3, "swipe_up"): return GestureTrigger.threeFingerSwipeUp
        case (3, "swipe_down"): return GestureTrigger.threeFingerSwipeDown
        case (3, "swipe_left"): return GestureTrigger.threeFingerSwipeLeft
        case (3, "swipe_right"): return GestureTrigger.threeFingerSwipeRight
        default: return ""
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

        // Cursor teleport: Ctrl+Opt+Right/Left
        let cursorNext = "Ampliky.cursor.warpNext()"
        let cursorNextFile = scriptStore.saveScript(content: cursorNext, name: "光标跳到下一个屏幕")
        configStore.addRule(Rule(
            id: UUID().uuidString, name: "光标跳到下一个屏幕",
            trigger: .hotkey(key: "ctrl+opt+right"),
            actions: [], enabled: true, source: "user", scriptPath: cursorNextFile
        ))

        let cursorPrev = "Ampliky.cursor.warpPrev()"
        let cursorPrevFile = scriptStore.saveScript(content: cursorPrev, name: "光标跳到上一个屏幕")
        configStore.addRule(Rule(
            id: UUID().uuidString, name: "光标跳到上一个屏幕",
            trigger: .hotkey(key: "ctrl+opt+left"),
            actions: [], enabled: true, source: "user", scriptPath: cursorPrevFile
        ))

        // Gesture: three-finger tap to jump to next screen
        let gestureScript = "Ampliky.cursor.warpNext()"
        let gestureFile = scriptStore.saveScript(content: gestureScript, name: "光标跳到下一个屏幕")
        configStore.addRule(Rule(
            id: UUID().uuidString, name: "光标跳屏（三指点击）",
            trigger: .gesture(fingers: 3, action: "tap"),
            actions: [], enabled: true, source: "user", scriptPath: gestureFile
        ))

        // Window management: Cmd+Opt+Left/Right/Up
        let winLeft = "Ampliky.window.leftHalf()"
        let winLeftFile = scriptStore.saveScript(content: winLeft, name: "窗口左半屏")
        configStore.addRule(Rule(
            id: UUID().uuidString, name: "窗口左半屏",
            trigger: .hotkey(key: "cmd+opt+left"),
            actions: [], enabled: true, source: "user", scriptPath: winLeftFile
        ))

        let winRight = "Ampliky.window.rightHalf()"
        let winRightFile = scriptStore.saveScript(content: winRight, name: "窗口右半屏")
        configStore.addRule(Rule(
            id: UUID().uuidString, name: "窗口右半屏",
            trigger: .hotkey(key: "cmd+opt+right"),
            actions: [], enabled: true, source: "user", scriptPath: winRightFile
        ))

        let winMax = "Ampliky.window.maximize()"
        let winMaxFile = scriptStore.saveScript(content: winMax, name: "窗口最大化")
        configStore.addRule(Rule(
            id: UUID().uuidString, name: "窗口最大化",
            trigger: .hotkey(key: "cmd+opt+up"),
            actions: [], enabled: true, source: "user", scriptPath: winMaxFile
        ))

        // System: Cmd+Opt+M for mute toggle
        let muteScript = "Ampliky.system.toggleMute()"
        let muteFile = scriptStore.saveScript(content: muteScript, name: "静音切换")
        configStore.addRule(Rule(
            id: UUID().uuidString, name: "静音切换",
            trigger: .hotkey(key: "cmd+opt+m"),
            actions: [], enabled: true, source: "user", scriptPath: muteFile
        ))

        // System: Cmd+Opt+L for lock screen
        let lockScript = "Ampliky.system.lockScreen()"
        let lockFile = scriptStore.saveScript(content: lockScript, name: "锁屏")
        configStore.addRule(Rule(
            id: UUID().uuidString, name: "锁屏",
            trigger: .hotkey(key: "cmd+opt+l"),
            actions: [], enabled: true, source: "user", scriptPath: lockFile
        ))

        Logger.shared.log(level: .info, message: "初始化默认快捷指令完成")
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
        case "exec":
            // Execute action by name (convenience method for CLI)
            guard let name = request.params["name"] as? String else {
                return SocketProtocol.errorResponse(id: request.id, code: -32602, message: "missing 'name' field")
            }
            let params = (request.params["params"] as? [String: String]) ?? [:]
            switch name {
            case "teleportCursor":
                if let to = params["to"] {
                    CursorAction.teleport(to: to)
                    return SocketProtocol.successResponse(id: request.id, result: ["success": true, "action": name])
                }
                return SocketProtocol.errorResponse(id: request.id, code: -32602, message: "missing 'to' param")
            case "screenCount":
                return SocketProtocol.successResponse(id: request.id, result: ["success": true, "count": NSScreen.screens.count])
            case "cursorPosition":
                let loc = NSEvent.mouseLocation
                return SocketProtocol.successResponse(id: request.id, result: ["success": true, "x": loc.x, "y": loc.y])
            default:
                return SocketProtocol.errorResponse(id: request.id, code: -32601, message: "Unknown action: \(name)")
            }
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
