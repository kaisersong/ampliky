import XCTest
@testable import Ampliky

final class ActionSchemaTests: XCTestCase {

    // MARK: - Valid actions

    func testValidTeleportCursor() {
        let json = """
        {"name": "teleportCursor", "params": {"to": "next_screen"}}
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validate(data)
        XCTAssertTrue(result.isValid)
    }

    func testValidLaunchApp() {
        let json = """
        {"name": "launchApp", "params": {"name": "Safari"}}
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validate(data)
        XCTAssertTrue(result.isValid)
    }

    func testValidMoveWindow() {
        let json = """
        {"name": "moveWindow", "params": {"app": "Warp", "to": "left_half"}}
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validate(data)
        XCTAssertTrue(result.isValid)
    }

    func testValidSetVolume() {
        let json = """
        {"name": "setVolume", "params": {"level": "mute"}}
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validate(data)
        XCTAssertTrue(result.isValid)
    }

    func testValidSetVolumeNumeric() {
        let json = """
        {"name": "setVolume", "params": {"level": 50}}
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validate(data)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Invalid actions

    func testUnknownAction() {
        let json = """
        {"name": "deleteEverything", "params": {}}
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validate(data)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("unknown action") }))
    }

    func testMissingName() {
        let json = """
        {"params": {"to": "next_screen"}}
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validate(data)
        XCTAssertFalse(result.isValid)
    }

    func testInvalidJSON() {
        let data = "not json".data(using: .utf8)!
        let result = ActionSchema.validate(data)
        XCTAssertFalse(result.isValid)
    }

    func testInvalidTeleportCursorTarget() {
        let json = """
        {"name": "teleportCursor", "params": {"to": "diagonally"}}
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validate(data)
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Rule validation

    func testValidRule() {
        let json = """
        {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "name": "cursor right",
          "trigger": {"type": "hotkey", "key": "cmd+opt+right"},
          "action": {"name": "teleportCursor", "params": {"to": "next_screen"}},
          "enabled": true,
          "source": "user"
        }
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validateRule(data)
        XCTAssertTrue(result.isValid)
    }

    func testRuleWithActionArray() {
        let json = """
        {
          "id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
          "name": "work mode",
          "trigger": {"type": "wifi", "ssid": "Office"},
          "action": [
            {"name": "launchApp", "params": {"name": "Warp"}},
            {"name": "launchApp", "params": {"name": "Slack"}}
          ],
          "enabled": true,
          "source": "ai"
        }
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validateRule(data)
        XCTAssertTrue(result.isValid)
    }

    func testRuleWithInvalidAction() {
        let json = """
        {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "name": "bad",
          "trigger": {"type": "hotkey", "key": "cmd+opt+x"},
          "action": {"name": "deleteEverything", "params": {}},
          "enabled": true,
          "source": "user"
        }
        """
        let data = json.data(using: .utf8)!
        let result = ActionSchema.validateRule(data)
        XCTAssertFalse(result.isValid)
    }
}
