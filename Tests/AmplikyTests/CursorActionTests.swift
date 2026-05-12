import XCTest
@testable import Ampliky

final class CursorActionTests: XCTestCase {
    func testResolveNextScreen() {
        let screens = [
            ScreenInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            ScreenInfo(id: 2, frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)),
        ]
        let next = CursorAction.resolveScreen(target: "next_screen", from: 0, screens: screens)
        XCTAssertEqual(next, 1)
    }

    func testResolvePrevScreen() {
        let screens = [
            ScreenInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            ScreenInfo(id: 2, frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)),
        ]
        let prev = CursorAction.resolveScreen(target: "prev_screen", from: 1, screens: screens)
        XCTAssertEqual(prev, 0)
    }

    func testResolveScreenN() {
        let screens = [
            ScreenInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            ScreenInfo(id: 2, frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)),
        ]
        let result = CursorAction.resolveScreen(target: "screen_2", from: 0, screens: screens)
        XCTAssertEqual(result, 1)
    }

    func testResolveScreenNOutOfRange() {
        let screens = [
            ScreenInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
        ]
        let result = CursorAction.resolveScreen(target: "screen_3", from: 0, screens: screens)
        XCTAssertNil(result)
    }

    func testResolveNextScreenWraps() {
        let screens = [
            ScreenInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            ScreenInfo(id: 2, frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)),
        ]
        let next = CursorAction.resolveScreen(target: "next_screen", from: 1, screens: screens)
        XCTAssertEqual(next, 0)
    }

    func testSingleScreenReturnsNil() {
        let screens = [
            ScreenInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
        ]
        let result = CursorAction.resolveScreen(target: "next_screen", from: 0, screens: screens)
        XCTAssertNil(result)
    }
}
