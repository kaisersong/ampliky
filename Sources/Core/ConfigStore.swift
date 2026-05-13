import Foundation

struct Rule: Codable, Equatable {
    let id: String
    let name: String
    let trigger: RuleTrigger
    let actions: [RuleAction]
    let enabled: Bool
    let source: String
    let scriptPath: String? // v2: path to JXA script in scripts/

    init(id: String, name: String, trigger: RuleTrigger,
         actions: [RuleAction], enabled: Bool, source: String,
         scriptPath: String? = nil) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.actions = actions
        self.enabled = enabled
        self.source = source
        self.scriptPath = scriptPath
    }

    private enum CodingKeys: String, CodingKey { case id, name, trigger, actions, enabled, source, scriptPath }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(trigger, forKey: .trigger)
        try c.encode(actions, forKey: .actions)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(source, forKey: .source)
        if let sp = scriptPath { try c.encode(sp, forKey: .scriptPath) }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        trigger = try c.decode(RuleTrigger.self, forKey: .trigger)
        actions = try c.decode([RuleAction].self, forKey: .actions)
        enabled = try c.decode(Bool.self, forKey: .enabled)
        source = try c.decode(String.self, forKey: .source)
        scriptPath = try c.decodeIfPresent(String.self, forKey: .scriptPath)
    }
}

struct RuleAction: Codable, Equatable {
    let name: String
    let params: [String: String]
}

enum RuleTrigger: Codable, Equatable {
    case hotkey(key: String)
    case wifi(ssid: String)
    case display(count: Int)
    case time(from: String, to: String)

    private enum CodingKeys: String, CodingKey { case type, key, ssid, count, from, to }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "hotkey": self = .hotkey(key: try c.decode(String.self, forKey: .key))
        case "wifi": self = .wifi(ssid: try c.decode(String.self, forKey: .ssid))
        case "display": self = .display(count: try c.decode(Int.self, forKey: .count))
        case "time": self = .time(from: try c.decode(String.self, forKey: .from), to: try c.decode(String.self, forKey: .to))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "unknown trigger type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hotkey(let key):
            try c.encode("hotkey", forKey: .type); try c.encode(key, forKey: .key)
        case .wifi(let ssid):
            try c.encode("wifi", forKey: .type); try c.encode(ssid, forKey: .ssid)
        case .display(let count):
            try c.encode("display", forKey: .type); try c.encode(count, forKey: .count)
        case .time(let from, let to):
            try c.encode("time", forKey: .type); try c.encode(from, forKey: .from); try c.encode(to, forKey: .to)
        }
    }
}

class ConfigStore {
    private let rulesFile: URL
    let scriptsDir: URL
    private let prefsFile: URL

    init(configDir: URL) {
        self.rulesFile = configDir.appendingPathComponent("rules.json")
        self.scriptsDir = configDir.appendingPathComponent("scripts")
        self.prefsFile = configDir.appendingPathComponent("prefs.json")
        try? FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
    }

    convenience init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".ampliky")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.init(configDir: dir)
    }

    func loadRules() -> [Rule] {
        guard let data = try? Data(contentsOf: rulesFile) else { return [] }
        return (try? JSONDecoder().decode([Rule].self, from: data)) ?? []
    }

    func addRule(_ rule: Rule) {
        var rules = loadRules()
        rules.append(rule)
        saveRules(rules)
    }

    func removeRule(id: String) {
        var rules = loadRules()
        rules.removeAll { $0.id == id }
        // Also delete script file
        let rule = (try? JSONDecoder().decode([Rule].self, from: try Data(contentsOf: rulesFile)))?.first { $0.id == id }
        if let sp = rule?.scriptPath {
            try? FileManager.default.removeItem(at: scriptsDir.appendingPathComponent(sp))
        }
        saveRules(rules)
    }

    private func saveRules(_ rules: [Rule]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try? encoder.encode(rules)
        try? data?.write(to: rulesFile, options: .atomic)
    }

    // MARK: - Preferences

    func shouldShowMenubar() -> Bool {
        guard let data = try? Data(contentsOf: prefsFile),
              let prefs = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return true // default: show menubar
        }
        return prefs["showMenubar"] as? Bool ?? true
    }

    func setShowMenubar(_ show: Bool) {
        let prefs: [String: Any] = ["showMenubar": show]
        let data = try? JSONSerialization.data(withJSONObject: prefs)
        try? data?.write(to: prefsFile, options: .atomic)
    }
}
