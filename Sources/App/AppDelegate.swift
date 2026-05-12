import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBar = MenuBarController()
    let configStore = ConfigStore()
    let contextMonitor = ContextMonitor()
    var ruleEngine: RuleEngine!
    var hotkeyTrigger: HotkeyTrigger!
    var socketServer: SocketServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar.setup()

        // Seed default rules on first launch
        if configStore.loadRules().isEmpty {
            let defaults = [
                Rule(id: UUID().uuidString, name: "Cursor to next screen",
                     trigger: .hotkey(key: "cmd+opt+right"),
                     actions: [RuleAction(name: "teleportCursor", params: ["to": "next_screen"])],
                     enabled: true, source: "user"),
                Rule(id: UUID().uuidString, name: "Cursor to prev screen",
                     trigger: .hotkey(key: "cmd+opt+left"),
                     actions: [RuleAction(name: "teleportCursor", params: ["to": "prev_screen"])],
                     enabled: true, source: "user"),
            ]
            for rule in defaults { configStore.addRule(rule) }
        }

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
                    self?.executeActions(rule.actions)
                }
            }
        }
    }

    private func executeActions(_ actions: [RuleAction]) {
        for action in actions {
            switch action.name {
            case "teleportCursor":
                if let to = action.params["to"] {
                    CursorAction.teleport(to: to)
                }
            case "launchApp":
                if let name = action.params["name"] {
                    AppAction.launch(name: name)
                }
            case "quitApp":
                if let name = action.params["name"] {
                    AppAction.quit(name: name)
                }
            default:
                break
            }
        }
    }

    private func handleRPC(_ request: RPCRequest) -> Data {
        switch request.method {
        case "run":
            guard let name = request.params["name"] as? String else {
                return SocketProtocol.errorResponse(id: request.id, code: -32602, message: "missing action name")
            }
            if name == "shellExec" {
                return SocketProtocol.errorResponse(id: request.id, code: -32600, message: "shellExec not allowed via socket")
            }
            let params = (request.params["params"] as? [String: String]) ?? [:]
            executeActions([RuleAction(name: name, params: params)])
            return SocketProtocol.successResponse(id: request.id, result: ["success": true, "action": name])

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

// Manual main entry point to ensure AppDelegate is connected
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
