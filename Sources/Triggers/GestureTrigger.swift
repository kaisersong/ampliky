import AppKit
import Carbon

// MARK: - Gesture Trigger using NSGestureRecognizer for multi-finger detection

class GestureTrigger {
    private var callbacks: [String: () -> Void] = [:]
    private var eventTap: CFMachPort?
    private var gestureView: NSView?
    private var gestureWindow: NSWindow?

    static let threeFingerTap = "threeFingerTap"
    static let threeFingerSwipeUp = "threeFingerSwipeUp"
    static let threeFingerSwipeDown = "threeFingerSwipeDown"
    static let threeFingerSwipeLeft = "threeFingerSwipeLeft"
    static let threeFingerSwipeRight = "threeFingerSwipeRight"

    // Track state for three-finger detection via CGEvent fallback
    private var isThreeFingerPending: Bool = false
    private var fingerDownTime: TimeInterval = 0

    func register(gesture: String, callback: @escaping () -> Void) {
        callbacks[gesture] = callback
    }

    func start() {
        // Create a hidden window to capture gesture recognizer events
        // NSGestureRecognizer requires a view in a window to work
        let window = NSWindow(contentRect: NSRect(x: -1000, y: -1000, width: 100, height: 100),
                              styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.hasShadow = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.orderFrontRegardless() // Keep it alive

        // Create a view with gesture recognizers
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        window.contentView = view

        // Three-finger press gesture
        let pressGesture = NSPressGestureRecognizer(target: self, action: #selector(threeFingerPressDetected(_:)))
        pressGesture.minimumPressDuration = 0
        pressGesture.numberOfTouchesRequired = 3
        view.addGestureRecognizer(pressGesture)

        // Pan gesture for swipe detection (three fingers)
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(panDetected(_:)))
        view.addGestureRecognizer(panGesture)

        gestureView = view
        gestureWindow = window

        // Also use CGEvent tap for swipe detection fallback
        let mask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let `self` = Unmanaged<GestureTrigger>.fromOpaque(refcon).takeUnretainedValue()
                self.handleScrollEvent(event)
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
        print("[Ampliky] Gesture trigger started - NSPressGestureRecognizer for 3-finger tap + CGEvent for swipe")
        #endif
    }

    func stop() {
        gestureView = nil
        gestureWindow?.orderOut(nil)
        gestureWindow = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    @objc private func threeFingerPressDetected(_ gesture: NSPressGestureRecognizer) {
        if gesture.state == .recognized || gesture.state == .ended {
            #if DEBUG
            print("[Ampliky] Three-finger tap detected via NSPressGestureRecognizer!")
            #endif
            fireThreeFingerTap()
        }
    }

    @objc private func panDetected(_ gesture: NSPanGestureRecognizer) {
        if gesture.state == .ended {
            let translation = gesture.translation(in: gesture.view)
            #if DEBUG
            print("[Ampliky] Pan gesture ended: x=\(translation.x), y=\(translation.y)")
            #endif

            if abs(translation.y) > abs(translation.x) {
                if translation.y < -20 {
                    if let cb = callbacks[GestureTrigger.threeFingerSwipeUp] {
                        #if DEBUG
                        print("[Ampliky] Three-finger swipe up via gesture")
                        #endif
                        cb()
                    }
                } else if translation.y > 20 {
                    if let cb = callbacks[GestureTrigger.threeFingerSwipeDown] {
                        #if DEBUG
                        print("[Ampliky] Three-finger swipe down via gesture")
                        #endif
                        cb()
                    }
                }
            } else {
                if translation.x > 20 {
                    if let cb = callbacks[GestureTrigger.threeFingerSwipeRight] {
                        #if DEBUG
                        print("[Ampliky] Three-finger swipe right via gesture")
                        #endif
                        cb()
                    }
                } else if translation.x < -20 {
                    if let cb = callbacks[GestureTrigger.threeFingerSwipeLeft] {
                        #if DEBUG
                        print("[Ampliky] Three-finger swipe left via gesture")
                        #endif
                        cb()
                    }
                }
            }
        }
    }

    private func handleScrollEvent(_ event: CGEvent) {
        let type = event.type
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        if type == .scrollWheel {
            let scrollX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            let scrollY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)

            if abs(scrollX) > 10 || abs(scrollY) > 10 {
                #if DEBUG
                print("[Ampliky] Scroll event: x=\(scrollX), y=\(scrollY)")
                #endif

                if abs(scrollY) > abs(scrollX) {
                    if scrollY > 0 {
                        if let cb = callbacks[GestureTrigger.threeFingerSwipeUp] {
                            #if DEBUG
                            print("[Ampliky] Three-finger swipe up via scroll")
                            #endif
                            cb()
                        }
                    } else {
                        if let cb = callbacks[GestureTrigger.threeFingerSwipeDown] {
                            #if DEBUG
                            print("[Ampliky] Three-finger swipe down via scroll")
                            #endif
                            cb()
                        }
                    }
                } else {
                    if scrollX > 0 {
                        if let cb = callbacks[GestureTrigger.threeFingerSwipeRight] {
                            #if DEBUG
                            print("[Ampliky] Three-finger swipe right via scroll")
                            #endif
                            cb()
                        }
                    } else {
                        if let cb = callbacks[GestureTrigger.threeFingerSwipeLeft] {
                            #if DEBUG
                            print("[Ampliky] Three-finger swipe left via scroll")
                            #endif
                            cb()
                        }
                    }
                }
            }
        }
    }

    private func fireThreeFingerTap() {
        if let cb = callbacks[GestureTrigger.threeFingerTap] {
            #if DEBUG
            print("[Ampliky] Firing three-finger tap callback")
            #endif
            cb()
        }
    }
}
