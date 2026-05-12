import Foundation

struct ValidationResult {
    let isValid: Bool
    let errors: [String]

    static let valid = ValidationResult(isValid: true, errors: [])
    static func invalid(_ errors: String...) -> ValidationResult {
        ValidationResult(isValid: false, errors: errors)
    }
}

enum ActionSchema {

    private static let actionDefs: [String: Set<String>] = [
        "teleportCursor": ["next_screen", "prev_screen", "center"],
        "moveWindow": ["left_half", "right_half", "top_half", "bottom_half", "fullscreen", "center"],
        "launchApp": [],
        "quitApp": [],
        "shellExec": [],
        "setVolume": ["mute"],
        "setLayout": [],
    ]

    private static func isValidTarget(for action: String, value: String) -> Bool {
        if let allowed = actionDefs[action], allowed.isEmpty {
            return true
        }
        if value.hasPrefix("screen_") { return true }
        if let allowed = actionDefs[action] {
            return allowed.contains(value)
        }
        return false
    }

    static func validate(_ data: Data) -> ValidationResult {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .invalid("invalid JSON")
        }
        return validateAction(obj)
    }

    private static func validateAction(_ obj: [String: Any]) -> ValidationResult {
        guard let name = obj["name"] as? String else {
            return .invalid("missing 'name' field")
        }
        guard actionDefs[name] != nil else {
            return .invalid("unknown action: \(name)")
        }
        guard let params = obj["params"] as? [String: Any] else {
            return .invalid("missing 'params' field")
        }

        switch name {
        case "teleportCursor":
            guard let to = params["to"] as? String, isValidTarget(for: name, value: to) else {
                return .invalid("invalid 'to' param for teleportCursor")
            }
        case "moveWindow":
            guard let app = params["app"] as? String, !app.isEmpty else {
                return .invalid("missing 'app' param for moveWindow")
            }
            guard let to = params["to"] as? String, isValidTarget(for: name, value: to) else {
                return .invalid("invalid 'to' param for moveWindow")
            }
        case "launchApp", "quitApp":
            guard let appName = params["name"] as? String, !appName.isEmpty else {
                return .invalid("missing 'name' param for \(name)")
            }
        case "shellExec":
            guard let command = params["command"] as? String, !command.isEmpty else {
                return .invalid("missing 'command' param for shellExec")
            }
        case "setVolume":
            if let level = params["level"] as? String {
                guard level == "mute" || Int(level) != nil else {
                    return .invalid("invalid 'level' param for setVolume")
                }
            } else if let level = params["level"] as? Int {
                guard (0...100).contains(level) else {
                    return .invalid("level must be 0-100")
                }
            } else {
                return .invalid("missing 'level' param for setVolume")
            }
        case "setLayout":
            guard let layoutName = params["name"] as? String, !layoutName.isEmpty else {
                return .invalid("missing 'name' param for setLayout")
            }
        default:
            break
        }
        return .valid
    }

    static func validateRule(_ data: Data) -> ValidationResult {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .invalid("invalid JSON")
        }
        guard obj["id"] is String else {
            return .invalid("missing 'id' field")
        }
        guard obj["trigger"] is [String: Any] else {
            return .invalid("missing 'trigger' field")
        }

        if let singleAction = obj["action"] as? [String: Any] {
            let result = validateAction(singleAction)
            if !result.isValid { return result }
        } else if let actionArray = obj["action"] as? [[String: Any]] {
            for action in actionArray {
                let result = validateAction(action)
                if !result.isValid { return result }
            }
        } else {
            return .invalid("missing or invalid 'action' field")
        }
        return .valid
    }
}
