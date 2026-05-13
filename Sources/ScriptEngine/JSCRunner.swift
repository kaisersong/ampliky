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
    }

    // Dry-run: execute script with mocked APIs to collect what it would do
    func dryRun(script: String) -> [String] {
        var calls: [String] = []

        let ctx = JSContext()!
        ctx.evaluateScript("eval = undefined;")
        ctx.evaluateScript("Function = undefined;")

        // Mock Ampliky APIs to just record calls
        ctx.setObject(unsafeBitCast({ (msg: String) in
            calls.append(msg)
        } as @convention(block) (String) -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_record" as NSString)

        ctx.evaluateScript("""
        var Ampliky = {
            screen: {
                count: function() { return 2; },
                list: function() { return JSON.stringify([{id:0,width:1920,height:1080},{id:1,width:2560,height:1440}]); },
                current: function() { return JSON.stringify({x:0,y:0,width:1920,height:1080}); }
            },
            cursor: {
                position: function() { return JSON.stringify({x:960,y:540}); },
                moveTo: function(x, y) { __ampliky_record('cursor.moveTo(' + x + ', ' + y + ')'); },
                warpNext: function() { __ampliky_record('cursor.warpNext()'); },
                warpPrev: function() { __ampliky_record('cursor.warpPrev()'); },
                warpTo: function(i) { __ampliky_record('cursor.warpTo(' + i + ')'); }
            },
            app: {
                launch: function(n) { __ampliky_record('app.launch("' + n + '")'); },
                quit: function(n) { __ampliky_record('app.quit("' + n + '")'); },
                running: function(n) { return false; },
                frontmost: function() { return 'Finder'; }
            },
            system: {
                clipboard: function(t) {
                    if (t !== undefined) { __ampliky_record('system.clipboard(set)'); return t; }
                    return '';
                }
            }
        };
        """)

        ctx.evaluateScript(script)

        return calls
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
            // If the JS value is an object, JSON.stringify it for proper output
            let output: String
            if result.isObject {
                let stringifyFn = context.objectForKeyedSubscript("JSON")?.objectForKeyedSubscript("stringify")
                output = stringifyFn?.call(withArguments: [result])?.toString() ?? result.toString() ?? ""
            } else {
                output = result.toString() ?? ""
            }
            return .ok(output, durationMs: duration)
        }

        return .ok("undefined", durationMs: duration)
    }

    private func registerAPIs() {
        context.evaluateScript("""
        var Ampliky = {
            screen: {
                count: function() { return __ampliky_screen_count(); },
                list: function() { return JSON.parse(__ampliky_screen_list()); },
                current: function() { return JSON.parse(__ampliky_screen_current()); }
            },
            cursor: {
                position: function() { return JSON.parse(__ampliky_cursor_position()); },
                moveTo: function(x, y) { __ampliky_cursor_moveTo(x, y); },
                warpNext: function() { __ampliky_cursor_warpNext(); },
                warpPrev: function() { __ampliky_cursor_warpPrev(); },
                warpTo: function(i) { __ampliky_cursor_warpTo(i); }
            },
            app: {
                launch: function(n) { __ampliky_app_launch(n); },
                quit: function(n) { __ampliky_app_quit(n); },
                running: function(n) { return __ampliky_app_running(n); },
                frontmost: function() { return __ampliky_app_frontmost(); }
            },
            system: {
                clipboard: function(t) {
                    if (t !== undefined) { __ampliky_clipboard_set(t); return t; }
                    return __ampliky_clipboard_get();
                },
                toggleMute: function() { __ampliky_system_toggleMute(); },
                lockScreen: function() { __ampliky_system_lockScreen(); }
            },
            window: {
                leftHalf: function() { __ampliky_window_leftHalf(); },
                rightHalf: function() { __ampliky_window_rightHalf(); },
                maximize: function() { __ampliky_window_maximize(); },
                center: function() { __ampliky_window_center(); }
            }
        };
        """)

        registerScreenAPIs()
        registerCursorAPIs()
        registerAppAPIs()
        registerSystemAPIs()
        registerWindowAPIs()
    }

    // MARK: - Screen APIs

    private func registerScreenAPIs() {
        context.setObject(unsafeBitCast({ () -> Int in
            NSScreen.screens.count
        } as @convention(block) () -> Int, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_screen_count" as NSString)

        context.setObject(unsafeBitCast({ () -> String in
            let screens = NSScreen.screens.enumerated().map { (i, s) -> [String: Any] in
                ["id": i, "x": s.frame.origin.x, "y": s.frame.origin.y,
                 "width": s.frame.width, "height": s.frame.height, "isMain": i == 0]
            }
            let data = try! JSONSerialization.data(withJSONObject: screens)
            return String(data: data, encoding: .utf8)!
        } as @convention(block) () -> String, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_screen_list" as NSString)

        context.setObject(unsafeBitCast({ () -> String in
            let screens = NSScreen.screens
            let mouseLoc = NSEvent.mouseLocation
            var current = screens.first!
            for screen in screens {
                if screen.frame.contains(mouseLoc) { current = screen; break }
            }
            let obj: [String: Any] = ["x": current.frame.origin.x, "y": current.frame.origin.y,
                                      "width": current.frame.width, "height": current.frame.height]
            let data = try! JSONSerialization.data(withJSONObject: obj)
            return String(data: data, encoding: .utf8)!
        } as @convention(block) () -> String, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_screen_current" as NSString)
    }

    // MARK: - Cursor APIs

    private func registerCursorAPIs() {
        context.setObject(unsafeBitCast({ () -> String in
            let loc = NSEvent.mouseLocation
            let data = try! JSONSerialization.data(withJSONObject: ["x": loc.x, "y": loc.y])
            return String(data: data, encoding: .utf8)!
        } as @convention(block) () -> String, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_cursor_position" as NSString)

        context.setObject(unsafeBitCast({ (x: Double, y: Double) in
            CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
        } as @convention(block) (Double, Double) -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_cursor_moveTo" as NSString)

        context.setObject(unsafeBitCast({ () in
            CursorAction.teleport(to: "next_screen")
        } as @convention(block) () -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_cursor_warpNext" as NSString)

        context.setObject(unsafeBitCast({ () in
            CursorAction.teleport(to: "prev_screen")
        } as @convention(block) () -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_cursor_warpPrev" as NSString)

        context.setObject(unsafeBitCast({ (i: Int) in
            CursorAction.teleport(to: "screen_\(i + 1)")
        } as @convention(block) (Int) -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_cursor_warpTo" as NSString)
    }

    // MARK: - App APIs

    private func registerAppAPIs() {
        context.setObject(unsafeBitCast({ (name: String) in
            let ws = NSWorkspace.shared
            if let url = ws.urlForApplication(withBundleIdentifier: name) {
                ws.open(url); return
            }
            ws.open(URL(fileURLWithPath: "/Applications/\(name).app"))
        } as @convention(block) (String) -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_app_launch" as NSString)

        context.setObject(unsafeBitCast({ (name: String) in
            NSWorkspace.shared.runningApplications
                .filter { $0.localizedName == name }
                .forEach { $0.terminate() }
        } as @convention(block) (String) -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_app_quit" as NSString)

        context.setObject(unsafeBitCast({ (name: String) -> Bool in
            NSWorkspace.shared.runningApplications.contains { $0.localizedName == name }
        } as @convention(block) (String) -> Bool, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_app_running" as NSString)

        context.setObject(unsafeBitCast({ () -> String in
            NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        } as @convention(block) () -> String, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_app_frontmost" as NSString)
    }

    // MARK: - System APIs

    private func registerSystemAPIs() {
        let pb = NSPasteboard.general

        context.setObject(unsafeBitCast({ () -> String in
            pb.string(forType: .string) ?? ""
        } as @convention(block) () -> String, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_clipboard_get" as NSString)

        context.setObject(unsafeBitCast({ (text: String) in
            pb.clearContents()
            pb.setString(text, forType: .string)
        } as @convention(block) (String) -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_clipboard_set" as NSString)

        // Toggle mute using AppleScript
        context.setObject(unsafeBitCast({ () in
            if let scriptObject = NSAppleScript(source: "set volume output muted not (output muted of (get volume settings))") {
                var error: NSDictionary?
                scriptObject.executeAndReturnError(&error)
            }
        } as @convention(block) () -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_system_toggleMute" as NSString)

        // Lock screen
        context.setObject(unsafeBitCast({ () in
            if let scriptObject = NSAppleScript(source: """
                tell application "System Events"
                    keystroke "q" using {command down, control down}
                end tell
                """) {
                var error: NSDictionary?
                scriptObject.executeAndReturnError(&error)
            }
        } as @convention(block) () -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_system_lockScreen" as NSString)
    }

    // MARK: - Window APIs

    private func registerWindowAPIs() {
        context.setObject(unsafeBitCast({ () in
            if let win = NSApp.mainWindow ?? NSApp.keyWindow {
                if let screen = win.screen {
                    var frame = screen.frame
                    frame.size.width /= 2
                    win.setFrame(frame, display: true, animate: true)
                }
            }
        } as @convention(block) () -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_window_leftHalf" as NSString)

        context.setObject(unsafeBitCast({ () in
            if let win = NSApp.mainWindow ?? NSApp.keyWindow {
                if let screen = win.screen {
                    var frame = screen.frame
                    frame.origin.x += frame.width / 2
                    frame.size.width /= 2
                    win.setFrame(frame, display: true, animate: true)
                }
            }
        } as @convention(block) () -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_window_rightHalf" as NSString)

        context.setObject(unsafeBitCast({ () in
            if let win = NSApp.mainWindow ?? NSApp.keyWindow {
                if let screen = win.screen {
                    win.setFrame(screen.frame, display: true, animate: true)
                }
            }
        } as @convention(block) () -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_window_maximize" as NSString)

        context.setObject(unsafeBitCast({ () in
            if let win = NSApp.mainWindow ?? NSApp.keyWindow {
                if let screen = win.screen {
                    let size = win.frame.size
                    var frame = screen.frame
                    frame.origin.x = (frame.width - size.width) / 2 + frame.origin.x
                    frame.origin.y = (frame.height - size.height) / 2 + frame.origin.y
                    win.setFrame(frame, display: true, animate: true)
                }
            }
        } as @convention(block) () -> Void, to: AnyObject.self),
        forKeyedSubscript: "__ampliky_window_center" as NSString)
    }
}
