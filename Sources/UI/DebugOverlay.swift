import AppKit
import Foundation

// MARK: - Debug Toast - small toast at top center of screen (below notch)

class DebugOverlayWindow: NSWindow {
    private var statusLabel: NSTextField!
    private var flashTimer: Timer?
    private static var shared: DebugOverlayWindow?

    static func show() {
        if shared == nil {
            shared = DebugOverlayWindow()
        }
        shared?.makeKeyAndOrderFront(nil)
    }

    static func hide() {
        shared?.orderOut(nil)
        shared = nil
    }

    static func flash(_ message: String, duration: Double = 2.0) {
        if shared == nil {
            shared = DebugOverlayWindow()
        }
        shared?.statusLabel.stringValue = message
        shared?.makeKeyAndOrderFront(nil)
        // Auto-hide after duration
        shared?.flashTimer?.invalidate()
        shared?.flashTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            shared?.statusLabel.stringValue = ""
            shared?.orderOut(nil)
        }
    }

    init() {
        // Small toast at top center, below the notch/dynamic island
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenWidth = screen.frame.width
        let toastWidth: CGFloat = 300
        let toastHeight: CGFloat = 28
        let frame = NSRect(
            x: screen.frame.origin.x + (screenWidth - toastWidth) / 2,
            y: screen.frame.maxY - 56, // below the notch
            width: toastWidth,
            height: toastHeight
        )
        super.init(contentRect: frame, styleMask: [.borderless],
                   backing: .buffered, defer: false)

        backgroundColor = NSColor.black.withAlphaComponent(0.7)
        isOpaque = false
        level = .floating
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .transient]

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 10, y: 4, width: toastWidth - 20, height: 20)
        statusLabel.textColor = NSColor.systemGreen
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        statusLabel.alignment = .center
        contentView?.addSubview(statusLabel)
    }
}

// MARK: - Action Feedback Toast - shown near cursor

class ActionToast {
    private static var toastWindow: NSWindow?
    private static var fadeTimer: Timer?

    static func show(action: String, shortcut: String? = nil) {
        let message = shortcut != nil ? "\(shortcut!) -> \(action)" : action

        if let existing = toastWindow {
            existing.orderOut(nil)
        }

        let mouseLoc = NSEvent.mouseLocation
        let frame = NSRect(x: mouseLoc.x - 80, y: mouseLoc.y + 24, width: 160, height: 28)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.backgroundColor = NSColor.black.withAlphaComponent(0.65)
        window.isOpaque = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .transient]

        let label = NSTextField(labelWithString: message)
        label.frame = NSRect(x: 8, y: 5, width: 144, height: 18)
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.alignment = .center
        window.contentView?.addSubview(label)

        window.makeKeyAndOrderFront(nil)
        toastWindow = window

        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            window.orderOut(nil)
            toastWindow = nil
        }
    }
}

// MARK: - Log Viewer

class LogViewerWindow: NSWindow {
    private var textView: NSTextView!
    private var timer: Timer?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 600, height: 300),
                   styleMask: [.titled, .closable, .resizable, .miniaturizable],
                   backing: .buffered, defer: false)
        title = "Ampliky Debug Log"
        isReleasedWhenClosed = false
        center()

        let scroll = NSScrollView(frame: contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true

        textView = NSTextView(frame: scroll.bounds)
        textView.isEditable = false
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = NSColor.windowBackgroundColor
        scroll.documentView = textView
        contentView?.addSubview(scroll)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }

        refresh()
    }

    private func refresh() {
        let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ampliky/logs.json")
        guard let data = try? Data(contentsOf: logFile),
              let logs = try? JSONDecoder().decode([LogEntry].self, from: data) else {
            textView?.string = "No logs yet"
            return
        }

        var text = ""
        for entry in logs.reversed() {
            let level = entry.level.rawValue
            let icon = level == "ERROR" ? "[ERR]" : (level == "DEBUG" ? "[DBG]" : "[INF]")
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let time = formatter.string(from: entry.timestamp)
            text += "[\(time)] \(icon) \(entry.message)\n"
        }
        textView?.string = text
    }
}
