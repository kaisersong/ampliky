import XCTest
@testable import Ampliky

final class ConfigStoreTests: XCTestCase {
    var tempDir: URL!
    var store: ConfigStore!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = ConfigStore(configDir: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLoadEmptyRules() {
        let rules = store.loadRules()
        XCTAssertTrue(rules.isEmpty)
    }

    func testAddAndLoadRule() {
        let rule = Rule(
            id: UUID().uuidString,
            name: "cursor right",
            trigger: .hotkey(key: "cmd+opt+right"),
            actions: [.init(name: "teleportCursor", params: ["to": "next_screen"])],
            enabled: true,
            source: "user"
        )
        store.addRule(rule)
        let loaded = store.loadRules()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "cursor right")
        XCTAssertEqual(loaded[0].id, rule.id)
    }

    func testRemoveRule() {
        let id = UUID().uuidString
        let rule = Rule(
            id: id,
            name: "test",
            trigger: .hotkey(key: "cmd+opt+x"),
            actions: [.init(name: "teleportCursor", params: ["to": "center"])],
            enabled: true,
            source: "user"
        )
        store.addRule(rule)
        store.removeRule(id: id)
        XCTAssertTrue(store.loadRules().isEmpty)
    }

    func testPersistAcrossInstances() {
        let rule = Rule(
            id: UUID().uuidString,
            name: "persist test",
            trigger: .hotkey(key: "cmd+opt+p"),
            actions: [.init(name: "teleportCursor", params: ["to": "center"])],
            enabled: true,
            source: "user"
        )
        store.addRule(rule)

        let store2 = ConfigStore(configDir: tempDir)
        let loaded = store2.loadRules()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "persist test")
    }

    func testDisabledRuleIsLoaded() {
        let rule = Rule(
            id: UUID().uuidString,
            name: "disabled",
            trigger: .hotkey(key: "cmd+opt+d"),
            actions: [.init(name: "teleportCursor", params: ["to": "center"])],
            enabled: false,
            source: "user"
        )
        store.addRule(rule)
        let loaded = store.loadRules()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertFalse(loaded[0].enabled)
    }
}
