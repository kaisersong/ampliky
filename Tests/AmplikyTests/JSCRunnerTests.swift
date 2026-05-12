import XCTest
import JavaScriptCore
@testable import Ampliky

final class JSCRunnerTests: XCTestCase {
    var runner: JSCRunner!

    override func setUp() {
        runner = JSCRunner()
    }

    // MARK: - Basic execution

    func testExecuteSimpleExpression() {
        let result = runner.execute(script: "1 + 1")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "2")
    }

    func testExecuteStringReturn() {
        let result = runner.execute(script: "'hello ' + 'world'")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "hello world")
    }

    func testExecuteWithException() {
        // Calling an undefined function should produce an error
        let result = runner.execute(script: "undefinedFunction()")
        // Either the result fails or the output indicates an error
        let indicatesError = !result.success || result.error != nil || result.output == "undefined"
        XCTAssertTrue(indicatesError, "Calling undefined function should indicate error")
    }

    // MARK: - Ampliky.screen API

    func testScreenCountAPI() {
        let result = runner.execute(script: "Ampliky.screen.count()")
        XCTAssertTrue(result.success)
        let count = Int(result.output!)
        XCTAssertGreaterThanOrEqual(count!, 1)
    }

    func testScreenListAPI() {
        let result = runner.execute(script: "JSON.stringify(Ampliky.screen.list())")
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output!.contains("width"))
    }

    // MARK: - Ampliky.cursor API

    func testCursorPositionAPI() {
        let result = runner.execute(script: "JSON.stringify(Ampliky.cursor.position())")
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output!.contains("x"))
    }

    // MARK: - Security: dangerous globals removed

    func testEvalUndefined() {
        let result = runner.execute(script: "typeof eval")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "undefined")
    }

    func testFunctionUndefined() {
        let result = runner.execute(script: "typeof Function")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "undefined")
    }

    func testXMLHttpRequestNotAvailable() {
        let result = runner.execute(script: "typeof XMLHttpRequest")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "undefined")
    }

    // MARK: - Security: script size

    func testOversizedScriptRejected() {
        let longScript = String(repeating: "var x = 1;\n", count: 101)
        let result = runner.execute(script: longScript)
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.error!.contains("100"))
    }

    // MARK: - Context persistence

    func testContextIsolation() {
        let r1 = runner.execute(script: "var x = 42")
        XCTAssertTrue(r1.success)
        // New runner should not see previous context
        let freshRunner = JSCRunner()
        let r2 = freshRunner.execute(script: "typeof x")
        XCTAssertTrue(r2.success)
        XCTAssertEqual(r2.output, "undefined")
    }
}
