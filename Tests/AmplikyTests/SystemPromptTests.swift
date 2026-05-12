import XCTest
@testable import Ampliky

final class SystemPromptTests: XCTestCase {
    func testBasePromptContainsAPIReference() {
        let prompt = SystemPrompt.build(intent: "跳到右边屏幕", context: "screens: 2")
        XCTAssertTrue(prompt.contains("Ampliky"))
        XCTAssertTrue(prompt.contains("cursor"))
    }

    func testSceneTemplateMatches() {
        let template = SystemPrompt.findSceneTemplate(intent: "把光标移到副屏")
        XCTAssertNotNil(template)
        XCTAssertTrue(template!.contains("cursor"))
    }

    func testContextInjected() {
        let prompt = SystemPrompt.build(intent: "test", context: "screens: 3, wifi: Office")
        XCTAssertTrue(prompt.contains("screens: 3"))
        XCTAssertTrue(prompt.contains("wifi: Office"))
    }

    func testSceneTemplateNoMatch() {
        let template = SystemPrompt.findSceneTemplate(intent: "做一些完全无关的事情")
        XCTAssertNil(template)
    }
}
