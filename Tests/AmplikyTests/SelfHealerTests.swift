import XCTest
@testable import Ampliky

final class SelfHealerTests: XCTestCase {
    func testBuildFixPrompt() {
        let prompt = SelfHealer.buildFixPrompt(
            originalIntent: "跳到右边屏幕",
            failedScript: "Ampliky.cursor.warpToNext()",
            errorMessage: "TypeError: Ampliky.cursor.warpToNext is not a function"
        )
        XCTAssertTrue(prompt.contains("warpToNext"))
        XCTAssertTrue(prompt.contains("跳到右边屏幕"))
        XCTAssertTrue(prompt.contains("修复"))
    }

    func testMaxRetries() {
        let healer = SelfHealer(maxRetries: 3)
        XCTAssertEqual(healer.maxRetries, 3)
        XCTAssertEqual(healer.currentAttempt, 0)
        XCTAssertTrue(healer.canRetry())
        healer.incrementAttempt()
        XCTAssertTrue(healer.canRetry())
        healer.incrementAttempt()
        XCTAssertTrue(healer.canRetry())
        healer.incrementAttempt()
        XCTAssertFalse(healer.canRetry())
    }
}
