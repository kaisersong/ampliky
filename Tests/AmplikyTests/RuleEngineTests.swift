import XCTest
@testable import Ampliky

final class RuleEngineTests: XCTestCase {
    func testHotkeyTriggerMatches() {
        let rules = [
            Rule(id: "1", name: "right", trigger: .hotkey(key: "cmd+opt+right"), actions: [.init(name: "teleportCursor", params: ["to": "next_screen"])], enabled: true, source: "user"),
            Rule(id: "2", name: "left", trigger: .hotkey(key: "cmd+opt+left"), actions: [.init(name: "teleportCursor", params: ["to": "prev_screen"])], enabled: true, source: "user"),
        ]
        let engine = RuleEngine(rules: rules)
        let result = engine.match(trigger: .hotkey(key: "cmd+opt+right"))
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.name, "right")
    }

    func testHotkeyNoMatch() {
        let rules = [
            Rule(id: "1", name: "right", trigger: .hotkey(key: "cmd+opt+right"), actions: [.init(name: "teleportCursor", params: ["to": "next_screen"])], enabled: true, source: "user"),
        ]
        let engine = RuleEngine(rules: rules)
        let result = engine.match(trigger: .hotkey(key: "cmd+opt+up"))
        XCTAssertNil(result)
    }

    func testDisabledRuleIgnored() {
        let rules = [
            Rule(id: "1", name: "right", trigger: .hotkey(key: "cmd+opt+right"), actions: [.init(name: "teleportCursor", params: ["to": "next_screen"])], enabled: false, source: "user"),
        ]
        let engine = RuleEngine(rules: rules)
        let result = engine.match(trigger: .hotkey(key: "cmd+opt+right"))
        XCTAssertNil(result)
    }

    func testMultipleActionsReturned() {
        let rules = [
            Rule(id: "1", name: "work", trigger: .wifi(ssid: "Office"), actions: [
                .init(name: "launchApp", params: ["name": "Warp"]),
                .init(name: "launchApp", params: ["name": "Slack"]),
            ], enabled: true, source: "ai"),
        ]
        let engine = RuleEngine(rules: rules)
        let result = engine.match(trigger: .wifi(ssid: "Office"))
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.actions.count, 2)
    }

    func testWifiTriggerDoesNotMatchHotkey() {
        let rules = [
            Rule(id: "1", name: "work", trigger: .wifi(ssid: "Office"), actions: [.init(name: "launchApp", params: ["name": "Warp"])], enabled: true, source: "ai"),
        ]
        let engine = RuleEngine(rules: rules)
        let result = engine.match(trigger: .hotkey(key: "cmd+opt+right"))
        XCTAssertNil(result)
    }

    func testDisplayTriggerMatches() {
        let rules = [
            Rule(id: "1", name: "dock", trigger: .display(count: 3), actions: [.init(name: "setLayout", params: ["name": "dock"])], enabled: true, source: "user"),
        ]
        let engine = RuleEngine(rules: rules)
        let result = engine.match(trigger: .display(count: 3))
        XCTAssertNotNil(result)
        XCTAssertNil(engine.match(trigger: .display(count: 2)))
    }
}
