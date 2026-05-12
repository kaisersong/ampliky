import XCTest
@testable import Ampliky

final class SocketProtocolTests: XCTestCase {
    func testParseValidRequest() {
        let data = """
        {"jsonrpc":"2.0","method":"run","params":{"name":"teleportCursor","params":{"to":"next_screen"}},"id":1}
        """.data(using: .utf8)!
        let request = SocketProtocol.parseRequest(data)
        XCTAssertNotNil(request)
        XCTAssertEqual(request!.method, "run")
        XCTAssertEqual(request!.id, 1)
    }

    func testParseInvalidJSON() {
        let data = "not json".data(using: .utf8)!
        let request = SocketProtocol.parseRequest(data)
        XCTAssertNil(request)
    }

    func testParseMissingMethod() {
        let data = """
        {"jsonrpc":"2.0","id":1}
        """.data(using: .utf8)!
        let request = SocketProtocol.parseRequest(data)
        XCTAssertNil(request)
    }

    func testBuildSuccessResponse() {
        let response = SocketProtocol.successResponse(id: 1, result: ["success": true])
        let obj = try! JSONSerialization.jsonObject(with: response) as! [String: Any]
        XCTAssertEqual(obj["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(obj["id"] as? Int, 1)
        XCTAssertNotNil(obj["result"])
    }

    func testBuildErrorResponse() {
        let response = SocketProtocol.errorResponse(id: 1, code: -32601, message: "Method not found")
        let obj = try! JSONSerialization.jsonObject(with: response) as! [String: Any]
        XCTAssertEqual(obj["jsonrpc"] as? String, "2.0")
        let error = obj["error"] as! [String: Any]
        XCTAssertEqual(error["code"] as? Int, -32601)
    }
}
