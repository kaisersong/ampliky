import AppKit
import Foundation

// MARK: - Debug Overlay - a thin bar at the top of the screen

class DebugOverlayWindow: NSWindow {
    private var statusLabel: NSTextField!
    private var timer: Timer?
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

    static func flash(_ message: String, duration: Double = 3.0) {
        if shared == nil {
            shared = DebugOverlayWindow()
            shared?.makeKeyAndOrderFront(nil)
        }
        shared?.statusLabel.stringValue = message
        // Fade out after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            shared?.statusLabel.stringValue = ""
        }
    }

    init() {
        // Get primary screen frame
        if let screen = NSScreen.main {
            let frame = NSRect(x: screen.frame.origin.x,
                              y: screen.frame.maxY - 24,
                              width: screen.frame.width,
                              height: 24)
            super.init(contentRect: frame, styleMask: [.borderless],
                       backing: .buffered, defer: false)
        } else {
            super.init(contentRect: NSRect(x: 0, y: 0, width: 1920, height: 24),
                       styleMask: [.borderless],
                       backing: .buffered, defer: false)
        }

        backgroundColor = NSColor.black.withAlphaComponent(0.85)
        isOpaque = false
        level = .screenSaver
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        statusLabel = NSTextField(labelWithString: "Ampliky Debug — 监听中...")
        statusLabel.frame = NSRect(x: 10, y: 3, width: contentView!.frame.width - 20, height: 18)
        statusLabel.textColor = .systemGreen
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        statusLabel.alignment = .left
        contentView?.addSubview(statusLabel)
    }
}

// MARK: - Action Feedback Toast

class ActionToast {
    private static var toastWindow: NSWindow?
    private static var fadeTimer: Timer?

    static func show(action: String, shortcut: String? = nil) {
        let message = shortcut != nil ? "⚡ \(shortcut!) → \(action)" : "⚡ \(action)"

        if let existing = toastWindow {
            existing.orderOut(nil)
        }

        // Get current cursor position for toast placement
        let mouseLoc = NSEvent.mouseLocation
        let frame = NSRect(x: mouseLoc.x - 100, y: mouseLoc.y + 30, width: 200, height: 32)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.backgroundColor = NSColor.black.withAlphaComponent(0.75)
        window.isOpaque = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .transient]

        let label = NSTextField(labelWithString: message)
        label.frame = NSRect(x: 10, y: 6, width: 180, height: 20)
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.alignment = .center
        window.contentView?.addSubview(label)

        window.makeKeyAndOrderFront(nil)
        toastWindow = window

        // Auto-hide after 2 seconds
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
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
        title = "Ampliky 调试日志"
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

        // Refresh every 1 second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }

        refresh()
    }

    private func refresh() {
        let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ampliky/logs.json")
        guard let data = try? Data(contentsOf: logFile),
              let logs = try? JSONDecoder().decode([LogEntry].self, from: data) else {
            textView?.string = "暂无日志"
            return
        }

        var text = ""
        for entry in logs.reversed() {
            let level = entry.level.rawValue
            let icon = level == "ERROR" ? "❌" : (level == "DEBUG" ? "🔧" : "✅")
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let time = formatter.string(from: entry.timestamp)
            text += "[\(time)] \(icon) \(entry.message)\n"
        }
        textView?.string = text
    }
}
