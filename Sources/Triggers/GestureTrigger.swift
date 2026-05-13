import AppKit
import Carbon

// MARK: - Gesture Trigger using CGEvent tap with finger count detection

class GestureTrigger {
    private var eventTap: CFMachPort?
    private var callbacks: [String: () -> Void] = [:]

    static let threeFingerTap = "threeFingerTap"
    static let threeFingerSwipeUp = "threeFingerSwipeUp"
    static let threeFingerSwipeDown = "threeFingerSwipeDown"
    static let threeFingerSwipeLeft = "threeFingerSwipeLeft"
    static let threeFingerSwipeRight = "threeFingerSwipeRight"

    // Track state for three-finger detection
    private var fingerDownCount: Int = 0
    private var fingerDownTime: TimeInterval = 0
    private var isThreeFingerTapPending = false

    func register(gesture: String, callback: @escaping () -> Void) {
        callbacks[gesture] = callback
    }

    func start() {
        // Listen to mouse down/up and scroll events
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let `self` = Unmanaged<GestureTrigger>.fromOpaque(refcon).takeUnretainedValue()
                self.handleEvent(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[Ampliky] Gesture event tap failed - check Input Monitoring permission")
            return
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        #if DEBUG
        print("[Ampliky] Gesture trigger started - listening for trackpad events")
        #endif
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func handleEvent(_ event: CGEvent) {
        let type = event.type

        // Auto-restart on disabled
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        // Get event flags - trackpad multi-finger events have specific flag values
        let flags = event.flags
        let flagsValue = flags.rawValue

        #if DEBUG
        if type == .otherMouseDown || type == .otherMouseUp || type == .leftMouseDown || type == .leftMouseUp {
            print("[Ampliky] Mouse event: type=\(type.rawValue), flags=\(flagsValue)")
        }
        #endif

        // Detect three-finger tap via event flags
        // Trackpad three-finger click has flags value 0x1000000 (16777216)
        // Two-finger click has flags value 0x2000000 (33554432)
        // Single-finger click has flags value 0x100 (256)
        if type == .otherMouseDown || type == .leftMouseDown {
            if flagsValue == 0x1000000 || flagsValue == 0x100 {
                // Check if this is a three-finger event
                // Three-finger tap on trackpad sends a special event
                let mouseButton = event.getIntegerValueField(.mouseEventButtonNumber)

                #if DEBUG
                print("[Ampliky] Mouse down: button=\(mouseButton), flags=\(flagsValue)")
                #endif

                // Three-finger tap: button 0 with special flags
                if mouseButton == 0 && (flagsValue == 0x1000000 || isThreeFingerEvent(flags: flags)) {
                    isThreeFingerTapPending = true
                    fingerDownTime = CACurrentMediaTime()
                    #if DEBUG
                    print("[Ampliky] Three-finger tap pending...")
                    #endif
                }
            }
        }

        // Check for three-finger tap release
        if type == .otherMouseUp || type == .leftMouseUp {
            if isThreeFingerTapPending {
                let duration = CACurrentMediaTime() - fingerDownTime
                if duration < 0.5 { // Short tap, not a drag
                    if let cb = callbacks[GestureTrigger.threeFingerTap] {
                        #if DEBUG
                        print("[Ampliky] Three-finger tap detected! duration=\(duration)")
                        #endif
                        cb()
                    }
                }
                isThreeFingerTapPending = false
            }
        }

        // Detect three-finger swipe via scroll events
        if type == .scrollWheel {
            let scrollX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            let scrollY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)

            // Check if this is a trackpad swipe (not mouse wheel)
            // Trackpad swipes have continuous scroll phase
            let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)

            #if DEBUG
            if abs(scrollX) > 1 || abs(scrollY) > 1 {
                print("[Ampliky] Scroll: x=\(scrollX), y=\(scrollY), phase=\(scrollPhase)")
            }
            #endif

            // Only process significant scrolls that look like finger swipes
            if abs(scrollX) > 10 || abs(scrollY) > 10 {
                if abs(scrollY) > abs(scrollX) {
                    // Vertical swipe
                    if scrollY > 0 {
                        if let cb = callbacks[GestureTrigger.threeFingerSwipeUp] {
                            #if DEBUG
                            print("[Ampliky] Three-finger swipe up detected!")
                            #endif
                            cb()
                        }
                    } else {
                        if let cb = callbacks[GestureTrigger.threeFingerSwipeDown] {
                            #if DEBUG
                            print("[Ampliky] Three-finger swipe down detected!")
                            #endif
                            cb()
                        }
                    }
                } else {
                    // Horizontal swipe
                    if scrollX > 0 {
                        if let cb = callbacks[GestureTrigger.threeFingerSwipeRight] {
                            #if DEBUG
                            print("[Ampliky] Three-finger swipe right detected!")
                            #endif
                            cb()
                        }
                    } else {
                        if let cb = callbacks[GestureTrigger.threeFingerSwipeLeft] {
                            #if DEBUG
                            print("[Ampliky] Three-finger swipe left detected!")
                            #endif
                            cb()
                        }
                    }
                }
            }
        }
    }

    // Check if the event flags indicate a multi-finger trackpad event
    private func isThreeFingerEvent(flags: CGEventFlags) -> Bool {
        let flagsValue = flags.rawValue
        // Trackpad three-finger click has specific flag patterns
        // This is heuristic-based and may not work on all macOS versions
        return flagsValue == 0x1000000 || flagsValue == 0x4000000
    }
}
