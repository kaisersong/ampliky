import AppKit

// MARK: - Edit Shortcut Window - allows modifying existing shortcuts

class EditShortcutWindow: NSWindow {
    private var shortcut: Rule
    private var triggerTypePopup: NSPopUpButton!
    private var hotkeyField: NSTextField!
    private var gestureFingersField: NSTextField!
    private var gestureActionPopup: NSPopUpButton!
    private var scriptView: NSTextView!
    private var nameField: NSTextField!

    weak var parentDelegate: ShortcutListWindowDelegate?

    init(shortcut: Rule) {
        self.shortcut = shortcut
        super.init(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                   styleMask: [.titled, .closable],
                   backing: .buffered, defer: false)
        title = "编辑快捷指令"
        isReleasedWhenClosed = false
        center()
        backgroundColor = NSColor.windowBackgroundColor
        buildUI()
    }

    private func buildUI() {
        let padding: CGFloat = 20
        var y = contentView!.frame.height - 30

        // Name field
        let nameLabel = NSTextField(labelWithString: "名称:")
        nameLabel.frame = NSRect(x: padding, y: y - 20, width: 50, height: 22)
        nameLabel.alignment = .right
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        contentView?.addSubview(nameLabel)

        nameField = NSTextField(frame: NSRect(x: padding + 60, y: y - 22, width: contentView!.frame.width - padding * 2 - 60, height: 24))
        nameField.stringValue = shortcut.name
        nameField.font = NSFont.systemFont(ofSize: 13)
        contentView?.addSubview(nameField)
        y -= 40

        // Trigger type
        let typeLabel = NSTextField(labelWithString: "触发器:")
        typeLabel.frame = NSRect(x: padding, y: y - 20, width: 50, height: 22)
        typeLabel.alignment = .right
        typeLabel.font = NSFont.systemFont(ofSize: 13)
        contentView?.addSubview(typeLabel)

        triggerTypePopup = NSPopUpButton(frame: NSRect(x: padding + 60, y: y - 22, width: 120, height: 24))
        triggerTypePopup.addItems(withTitles: ["快捷键", "触控板手势"])
        triggerTypePopup.target = self
        triggerTypePopup.action = #selector(triggerTypeChanged)
        contentView?.addSubview(triggerTypePopup)

        // Hotkey field (shown when trigger type is hotkey)
        hotkeyField = NSTextField(frame: NSRect(x: padding + 190, y: y - 22, width: 200, height: 24))
        hotkeyField.placeholderString = "cmd+opt+right"
        hotkeyField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        contentView?.addSubview(hotkeyField)

        // Gesture fields (shown when trigger type is gesture)
        gestureFingersField = NSTextField(frame: NSRect(x: padding + 190, y: y - 22, width: 40, height: 24))
        gestureFingersField.placeholderString = "3"
        gestureFingersField.isHidden = true
        contentView?.addSubview(gestureFingersField)

        let gestureActionLabel = NSTextField(labelWithString: "指")
        gestureActionLabel.frame = NSRect(x: padding + 235, y: y - 20, width: 20, height: 22)
        gestureActionLabel.isHidden = true
        contentView?.addSubview(gestureActionLabel)

        gestureActionPopup = NSPopUpButton(frame: NSRect(x: padding + 255, y: y - 22, width: 120, height: 24))
        gestureActionPopup.addItems(withTitles: ["点击", "上滑", "下滑", "左滑", "右滑"])
        gestureActionPopup.isHidden = true
        contentView?.addSubview(gestureActionPopup)

        // Set initial values based on trigger type
        switch shortcut.trigger {
        case .hotkey(let key):
            triggerTypePopup.selectItem(at: 0)
            hotkeyField.stringValue = key
        case .gesture(let fingers, let action):
            triggerTypePopup.selectItem(at: 1)
            hotkeyField.isHidden = true
            gestureFingersField.isHidden = false
            gestureActionLabel.isHidden = false
            gestureActionPopup.isHidden = false
            gestureFingersField.stringValue = "\(fingers)"
            let actionIndex: Int
            switch action {
            case "tap": actionIndex = 0
            case "swipe_up": actionIndex = 1
            case "swipe_down": actionIndex = 2
            case "swipe_left": actionIndex = 3
            case "swipe_right": actionIndex = 4
            default: actionIndex = 0
            }
            gestureActionPopup.selectItem(at: actionIndex)
        default:
            break
        }

        y -= 40

        // Script view
        let scriptLabel = NSTextField(labelWithString: "脚本:")
        scriptLabel.frame = NSRect(x: padding, y: y - 20, width: 50, height: 22)
        scriptLabel.alignment = .right
        scriptLabel.font = NSFont.systemFont(ofSize: 13)
        contentView?.addSubview(scriptLabel)

        let scriptScroll = NSScrollView(frame: NSRect(x: padding + 60, y: y - 100, width: contentView!.frame.width - padding * 2 - 60, height: 80))
        scriptScroll.hasVerticalScroller = true
        scriptView = NSTextView(frame: scriptScroll.bounds)
        scriptView.isRichText = false
        scriptView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        scriptScroll.documentView = scriptView
        contentView?.addSubview(scriptScroll)

        // Load script content
        if let scriptPath = shortcut.scriptPath {
            let scriptFile = ConfigStore().scriptsDir.appendingPathComponent(scriptPath)
            if let content = try? String(contentsOf: scriptFile, encoding: .utf8) {
                scriptView.string = content
            }
        } else if !shortcut.actions.isEmpty {
            // Fallback: show actions as pseudo-script
            scriptView.string = shortcut.actions.map { "\($0.name)(\($0.params))" }.joined(separator: "\n")
        }

        y -= 120

        // Buttons
        let saveBtn = NSButton(title: "保存", target: self, action: #selector(save))
        saveBtn.frame = NSRect(x: padding, y: y - 30, width: 60, height: 30)
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        contentView?.addSubview(saveBtn)

        let cancelBtn = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelBtn.frame = NSRect(x: padding + 70, y: y - 30, width: 60, height: 30)
        cancelBtn.bezelStyle = .rounded
        contentView?.addSubview(cancelBtn)
    }

    @objc private func triggerTypeChanged() {
        let isHotkey = triggerTypePopup.indexOfSelectedItem == 0
        hotkeyField.isHidden = !isHotkey
        gestureFingersField.isHidden = isHotkey
        gestureActionPopup.isHidden = isHotkey
    }

    @objc private func save() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        // Build trigger
        let trigger: RuleTrigger
        if triggerTypePopup.indexOfSelectedItem == 0 {
            // Hotkey
            let key = hotkeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            trigger = .hotkey(key: key)
        } else {
            // Gesture
            let fingers = Int(gestureFingersField.stringValue) ?? 3
            let actionIndex = gestureActionPopup.indexOfSelectedItem
            let action: String
            switch actionIndex {
            case 0: action = "tap"
            case 1: action = "swipe_up"
            case 2: action = "swipe_down"
            case 3: action = "swipe_left"
            case 4: action = "swipe_right"
            default: action = "tap"
            }
            trigger = .gesture(fingers: fingers, action: action)
        }

        // Save script
        let scriptContent = scriptView.string
        let scriptStore = ScriptStore()
        let filename: String

        if let oldPath = shortcut.scriptPath {
            // Update existing script file
            scriptStore.updateScript(filename: oldPath, content: scriptContent)
            filename = oldPath
        } else {
            // Create new script file
            filename = scriptStore.saveScript(content: scriptContent, name: name)
        }

        // Update rule
        let store = ConfigStore()
        store.removeRule(id: shortcut.id)
        let updatedRule = Rule(
            id: shortcut.id,
            name: name,
            trigger: trigger,
            actions: shortcut.actions,
            enabled: shortcut.enabled,
            source: shortcut.source,
            scriptPath: filename
        )
        store.addRule(updatedRule)

        Logger.shared.log(level: .info, message: "更新快捷指令: \(name)")

        // Notify parent to refresh
        parentDelegate?.shortcutListWindowDidUpdate()

        close()
    }

    @objc private func cancel() {
        close()
    }
}

protocol ShortcutListWindowDelegate: AnyObject {
    func shortcutListWindowDidUpdate()
}
