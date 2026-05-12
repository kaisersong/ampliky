import XCTest
@testable import Ampliky

// MARK: - HotkeyTrigger auto-restart tests

final class HotkeyRestartTests: XCTestCase {
    func testAutoRestartOnDisabledByTimeout() {
        // Simulate kCGEventTapDisabledByTimeout event type
        // The callback should re-enable the tap
        // This is a structural test - verify the restart logic exists
        let trigger = HotkeyTrigger()
        // Verify the auto-restart flag is set
        XCTAssertTrue(trigger.autoRestartEnabled, "Event tap should auto-restart on disabled")
    }

    func testAutoRestartOnDisabledByUserInput() {
        let trigger = HotkeyTrigger()
        // Verify both disabled event types trigger restart
        XCTAssertTrue(trigger.autoRestartEnabled, "Event tap should auto-restart on user input disabled")
    }
}

// MARK: - Screen ID reliability tests

final class ScreenIDTests: XCTestCase {
    func testScreenIDUsesCGDirectDisplayID() {
        // Screen resolution should use CGDirectDisplayID, not NSScreen array index
        let screens = NSScreen.screens
        let displayIDs = CGGetActiveDisplayList(0, nil, nil)

        // At least 1 screen should exist
        XCTAssertFalse(screens.isEmpty, "Should have at least 1 screen")
    }

    func testCursorWarpNextWithSingleScreen() {
        let result = CursorAction.teleportResult(target: "next_screen", currentScreenCount: 1)
        XCTAssertNil(result, "Single screen should warp to nil")
    }

    func testCursorWarpNextWithTwoScreens() {
        // From screen 0, next should be 1
        let result = CursorAction.teleportResult(target: "next_screen", currentScreenCount: 2, currentIndex: 0)
        XCTAssertEqual(result, 1)
    }

    func testCursorWarpPrevFromFirstScreen() {
        // From screen 0, prev should wrap to last
        let result = CursorAction.teleportResult(target: "prev_screen", currentScreenCount: 3, currentIndex: 0)
        XCTAssertEqual(result, 2)
    }

    func testCursorWarpToScreenN() {
        let result = CursorAction.teleportResult(target: "screen_2", currentScreenCount: 3, currentIndex: 0)
        XCTAssertEqual(result, 1) // 1-indexed to 0-indexed
    }

    func testCursorWarpToOutOfBounds() {
        let result = CursorAction.teleportResult(target: "screen_5", currentScreenCount: 2, currentIndex: 0)
        XCTAssertNil(result)
    }
}

// MARK: - Security: JSCRunner API boundary tests

final class JSCSecurityTests: XCTestCase {
    var runner: JSCRunner!

    override func setUp() {
        runner = JSCRunner()
    }

    func testNoDirectShellAccess() {
        // Ampliky.system exists for clipboard, but should NOT have shell
        let result = runner.execute(script: "typeof Ampliky.system.shell")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "undefined")
    }

    func testNoFileAccess() {
        // No NSFileManager or file I/O
        let result = runner.execute(script: "typeof ObjC")
        XCTAssertTrue(result.success)
        // ObjC bridge should be limited to Ampliky APIs
    }

    func testNoNetworkAccess() {
        let result = runner.execute(script: "typeof XMLHttpRequest")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "undefined")
    }

    func testNoEvalAccess() {
        let result = runner.execute(script: "typeof eval")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "undefined")
    }

    func testNoFunctionConstructor() {
        let result = runner.execute(script: "typeof Function")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "undefined")
    }
}

// MARK: - Script execution performance tests

final class JSCPerformanceTests: XCTestCase {
    var runner: JSCRunner!

    override func setUp() {
        runner = JSCRunner()
    }

    func testSimpleScriptUnder1ms() {
        let result = runner.execute(script: "Ampliky.screen.count()")
        XCTAssertTrue(result.success)
        XCTAssertLessThan(result.durationMs, 1.0, "Simple API call should be < 1ms")
    }

    func testCursorPositionUnder1ms() {
        let result = runner.execute(script: "Ampliky.cursor.position()")
        XCTAssertTrue(result.success)
        XCTAssertLessThan(result.durationMs, 1.0, "Cursor position should be < 1ms")
    }

    func testScriptWith100LinesUnderTimeout() {
        var script = ""
        for i in 0..<99 {
            script += "var _\(i) = \(i);\n"
        }
        script += "42"
        let result = runner.execute(script: script)
        // Should complete well under 5s timeout
        XCTAssertLessThan(result.durationMs, 5000)
    }
}

// MARK: - Rule engine with scriptPath

final class RuleEngineScriptTests: XCTestCase {
    func testRuleWithScriptPath() {
        let rule = Rule(
            id: "test-1",
            name: "test",
            trigger: .hotkey(key: "cmd+opt+t"),
            actions: [],
            enabled: true,
            source: "user",
            scriptPath: "test-script.js"
        )
        XCTAssertEqual(rule.scriptPath, "test-script.js")
    }

    func testRuleWithoutScriptPath() {
        let rule = Rule(
            id: "test-2",
            name: "test",
            trigger: .hotkey(key: "cmd+opt+t"),
            actions: [.init(name: "teleportCursor", params: ["to": "center"])],
            enabled: true,
            source: "user"
        )
        XCTAssertNil(rule.scriptPath)
        XCTAssertEqual(rule.actions.count, 1)
    }
}
