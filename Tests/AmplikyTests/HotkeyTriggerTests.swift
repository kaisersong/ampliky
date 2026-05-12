import XCTest
@testable import Ampliky

final class HotkeyTriggerTests: XCTestCase {
    func testParseKeyString() {
        let (mods, key) = HotkeyTrigger.parseKeySpec("cmd+opt+right")!
        XCTAssertTrue(mods.contains(.command))
        XCTAssertTrue(mods.contains(.option))
        XCTAssertEqual(key, .right)
    }

    func testParseSingleKey() {
        let (mods, key) = HotkeyTrigger.parseKeySpec("cmd+c")!
        XCTAssertTrue(mods.contains(.command))
        XCTAssertEqual(key, .c)
    }

    func testParseInvalidKey() {
        let result = HotkeyTrigger.parseKeySpec("invalid")
        XCTAssertNil(result)
    }
}
