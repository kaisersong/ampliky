import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBar = MenuBarController()
    let configStore = ConfigStore()
    let contextMonitor = ContextMonitor()
    let jscRunner = JSCRunner()
    var ruleEngine: RuleEngine!
    var hotkeyTrigger: HotkeyTrigger!
    var socketServer: SocketServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar.setup()

        let rules = configStore.loadRules()
        ruleEngine = RuleEngine(rules: rules)

        hotkeyTrigger = HotkeyTrigger()
        registerHotkeys(rules: rules)
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
        guard let scriptPath = rule.scriptPath else {
            for action in rule.actions {
                executeFallbackAction(action)
            }
            return
        }
        let fullPath = configStore.scriptsDir.appendingPathComponent(scriptPath).path
        guard let script = try? String(contentsOfFile: fullPath) else { return }
        let result = jscRunner.execute(script: script)
        if !result.success, let error = result.error {
            print("[Ampliky] script error: \(error)")
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
