import Foundation
import JavaScriptCore
import AppKit

struct ScriptResult {
    let success: Bool
    let output: String?
    let error: String?
    let durationMs: Double

    static func ok(_ output: String, durationMs: Double = 0) -> ScriptResult {
        ScriptResult(success: true, output: output, error: nil, durationMs: durationMs)
    }

    static func fail(_ error: String, durationMs: Double = 0) -> ScriptResult {
        ScriptResult(success: false, output: nil, error: error, durationMs: durationMs)
    }
}

class JSCRunner {
    private let context: JSContext
    private let maxLines = 100

    init() {
        context = JSContext()

        // Delete dangerous globals
        context.evaluateScript("eval = undefined;")
        context.evaluateScript("Function = undefined;")

        registerAPIs()

        // Don't set exceptionHandler — let exceptions surface via context.exception
    }

    func execute(script: String) -> ScriptResult {
        // Size check
        let lineCount = script.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        if lineCount > maxLines {
            return .fail("Script exceeds \(maxLines) lines (\(lineCount) lines)")
        }

        let start = CFAbsoluteTimeGetCurrent()

        let result = context.evaluateScript(script)

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        if let exception = context.exception {
            let msg = exception.toString() ?? "Unknown JS error"
            context.exception = nil
            return .fail(msg, durationMs: duration)
        }

        if let result = result, !result.isUndefined {
            return .ok(result.toString() ?? "", durationMs: duration)
        }

        return .ok("undefined", durationMs: duration)
    }

    private func registerAPIs() {
        let api = """
        var Ampliky = {
            screen: {
                count: function() {
                    return __ampliky_screen_count();
                },
                list: function() {
                    return JSON.parse(__ampliky_screen_list());
                },
                current: function() {
                    return JSON.parse(__ampliky_screen_current());
                }
            },
            cursor: {
                position: function() {
                    return JSON.parse(__ampliky_cursor_position());
                },
                moveTo: function(x, y) {
                    __ampliky_cursor_moveTo(x, y);
                },
                warpNext: function() {
                    __ampliky_cursor_warpNext();
                },
                warpPrev: function() {
                    __ampliky_cursor_warpPrev();
                },
                warpTo: function(screenIndex) {
                    __ampliky_cursor_warpTo(screenIndex);
                }
            }
        };
        """
        context.evaluateScript(api)

        // Register Swift-backed functions
        registerScreenAPIs()
        registerCursorAPIs()
    }

    private func registerScreenAPIs() {
        let ctx = context

        ctx.setObject(unsafeBitCast(({ () -> Int in
            NSScreen.screens.count
        }) as @convention(block) () -> Int, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_screen_count" as NSString)

        ctx.setObject(unsafeBitCast(({ () -> String in
            let screens = NSScreen.screens.enumerated().map { (i, s) -> [String: Any] in
                return ["id": i, "x": s.frame.origin.x, "y": s.frame.origin.y,
                        "width": s.frame.width, "height": s.frame.height,
                        "isMain": i == 0]
            }
            let data = try! JSONSerialization.data(withJSONObject: screens)
            return String(data: data, encoding: .utf8)!
        }) as @convention(block) () -> String, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_screen_list" as NSString)

        ctx.setObject(unsafeBitCast(({ () -> String in
            let screens = NSScreen.screens
            let mouseLoc = NSEvent.mouseLocation
            var current = screens.first!
            for screen in screens {
                if screen.frame.contains(mouseLoc) {
                    current = screen
                    break
                }
            }
            let obj: [String: Any] = ["x": current.frame.origin.x, "y": current.frame.origin.y,
                                      "width": current.frame.width, "height": current.frame.height]
            let data = try! JSONSerialization.data(withJSONObject: obj)
            return String(data: data, encoding: .utf8)!
        }) as @convention(block) () -> String, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_screen_current" as NSString)
    }

    private func registerCursorAPIs() {
        let ctx = context

        ctx.setObject(unsafeBitCast(({ () -> String in
            let loc = NSEvent.mouseLocation
            let obj: [String: Any] = ["x": loc.x, "y": loc.y]
            let data = try! JSONSerialization.data(withJSONObject: obj)
            return String(data: data, encoding: .utf8)!
        }) as @convention(block) () -> String, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_cursor_position" as NSString)

        ctx.setObject(unsafeBitCast(({ (_ x: Double, _ y: Double) -> Void in
            CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
        }) as @convention(block) (Double, Double) -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_cursor_moveTo" as NSString)

        ctx.setObject(unsafeBitCast(({ () -> Void in
            CursorAction.teleport(to: "next_screen")
        }) as @convention(block) () -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_cursor_warpNext" as NSString)

        ctx.setObject(unsafeBitCast(({ () -> Void in
            CursorAction.teleport(to: "prev_screen")
        }) as @convention(block) () -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_cursor_warpPrev" as NSString)

        ctx.setObject(unsafeBitCast(({ (_ screenIndex: Int) -> Void in
            CursorAction.teleport(to: "screen_\(screenIndex + 1)")
        }) as @convention(block) (Int) -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_cursor_warpTo" as NSString)
    }
}
