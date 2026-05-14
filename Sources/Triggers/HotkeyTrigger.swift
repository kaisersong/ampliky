import AppKit
import Carbon

class HotkeyTrigger {
    private var eventTap: CFMachPort?
    private var hotkeyCallbacks: [String: () -> Void] = [:]
    var autoRestartEnabled: Bool = true

    static func parseKeySpec(_ spec: String) -> (NSEvent.ModifierFlags, Key)? {
        let parts = spec.lowercased().split(separator: "+").map(String.init)
        guard !parts.isEmpty else { return nil }

        var mods: NSEvent.ModifierFlags = []
        for part in parts.dropLast() {
            switch part {
            case "cmd", "command": mods.insert(.command)
            case "opt", "option", "alt": mods.insert(.option)
            case "ctrl", "control": mods.insert(.control)
            case "shift": mods.insert(.shift)
            default: return nil
            }
        }

        guard let key = Key(rawValue: parts.last!) else { return nil }
        return (mods, key)
    }

    enum Key: String {
        case a, b, c, d, e, f, g, h, i, j, k, l, m
        case n, o, p, q, r, s, t, u, v, w, x, y, z
        case num0 = "0", num1 = "1", num2 = "2", num3 = "3", num4 = "4"
        case num5 = "5", num6 = "6", num7 = "7", num8 = "8", num9 = "9"
        case left = "left", right = "right", up = "up", down = "down"
        case space = "space", tab = "tab", enter = "enter", escape = "esc"
        case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
    }

    func register(keySpec: String, callback: @escaping () -> Void) {
        hotkeyCallbacks[keySpec] = callback
    }

    func start() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let `self` = Unmanaged<HotkeyTrigger>.fromOpaque(refcon).takeUnretainedValue()
                self.handleEvent(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[Ampliky] ⚠️ Hotkey event tap failed to create — check Input Monitoring permission")
            return
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func handleEvent(_ event: CGEvent) {
        // Auto-restart on disabled (Hammerspoon pattern)
        let type = event.type
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue))

        #if DEBUG
        print("[Ampliky] Key event: keyCode=\(keyCode), flags=\(flags.rawValue), nsFlags=\(nsFlags.rawValue)")
        #endif

        for (keySpec, callback) in hotkeyCallbacks {
            guard let (expectedMods, expectedKey) = HotkeyTrigger.parseKeySpec(keySpec) else { continue }
            let expectedKeyCode = Self.keyCode(for: expectedKey)
            #if DEBUG
            print("[Ampliky] Checking \(keySpec): expected keyCode=\(expectedKeyCode), expected mods=\(expectedMods.rawValue)")
            #endif
            if keyCode == expectedKeyCode && nsFlags.contains(expectedMods) {
                #if DEBUG
                print("[Ampliky] MATCH! Firing callback for \(keySpec)")
                #endif
                callback()
            }
        }
    }

    private static func keyCode(for key: Key) -> Int64 {
        switch key {
        case .a: return 0; case .b: return 11; case .c: return 8; case .d: return 2
        case .e: return 14; case .f: return 3; case .g: return 5; case .h: return 4
        case .i: return 34; case .j: return 38; case .k: return 40; case .l: return 37
        case .m: return 46; case .n: return 45; case .o: return 31; case .p: return 35
        case .q: return 12; case .r: return 15; case .s: return 1; case .t: return 17
        case .u: return 32; case .v: return 9; case .w: return 13; case .x: return 7
        case .y: return 16; case .z: return 6
        case .left: return 123; case .right: return 124; case .up: return 126; case .down: return 125
        case .space: return 49; case .tab: return 48; case .enter: return 36; case .escape: return 53
        case .f1: return 122; case .f2: return 120; case .f3: return 99; case .f4: return 118
        case .f5: return 96; case .f6: return 97; case .f7: return 98; case .f8: return 100
        case .f9: return 101; case .f10: return 109; case .f11: return 103; case .f12: return 111
        default: return -1
        }
    }
}
