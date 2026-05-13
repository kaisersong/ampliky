import AppKit

// MARK: - Modern Shortcut List Window

class ShortcutListWindow: NSWindow {
    private var tableView: NSTableView!
    private var shortcuts: [Rule] = []

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 580, height: 380),
                   styleMask: [.titled, .closable, .resizable],
                   backing: .buffered, defer: false)
        title = "快捷指令列表"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 450, height: 280)
        center()
        backgroundColor = NSColor.windowBackgroundColor
        buildUI()
        loadShortcuts()
    }

    private func buildUI() {
        let toolbar = NSView(frame: NSRect(x: 0, y: contentView!.frame.height - 40, width: contentView!.frame.width, height: 40))
        toolbar.autoresizingMask = [.width, .minYMargin]
        contentView?.addSubview(toolbar)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: contentView!.frame.width, height: contentView!.frame.height - 40))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        contentView?.addSubview(scroll)

        tableView = NSTableView(frame: scroll.bounds)
        tableView.autoresizingMask = [.width]
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.selectionHighlightStyle = .regular
        tableView.focusRingType = .none

        // Enable/disable column
        let enabledCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        enabledCol.title = "启用"
        enabledCol.minWidth = 50; enabledCol.maxWidth = 50
        tableView.addTableColumn(enabledCol)

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "名称"
        nameCol.minWidth = 160; nameCol.maxWidth = 200
        tableView.addTableColumn(nameCol)

        let triggerCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("trigger"))
        triggerCol.title = "触发器"
        triggerCol.minWidth = 140; triggerCol.maxWidth = 180
        tableView.addTableColumn(triggerCol)

        let descCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("desc"))
        descCol.title = "脚本"
        descCol.minWidth = 100
        tableView.addTableColumn(descCol)

        tableView.dataSource = self
        tableView.delegate = self
        scroll.documentView = tableView

        let deleteBtn = NSButton(title: "删除选中", target: self, action: #selector(deleteSelected))
        deleteBtn.frame = NSRect(x: 15, y: 5, width: 70, height: 30)
        deleteBtn.bezelStyle = .rounded
        deleteBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        toolbar.addSubview(deleteBtn)
    }

    func refresh() {
        loadShortcuts()
    }

    private func loadShortcuts() {
        let store = ConfigStore()
        shortcuts = store.loadRules()
        tableView.reloadData()
    }

    @objc private func deleteSelected() {
        guard tableView.selectedRow >= 0 else { return }
        let shortcut = shortcuts[tableView.selectedRow]

        let alert = NSAlert()
        alert.messageText = "删除快捷指令"
        alert.informativeText = "确定要删除「\(shortcut.name)」吗？"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            let store = ConfigStore()
            store.removeRule(id: shortcut.id)
            Logger.shared.log(level: .info, message: "删除快捷指令: \(shortcut.name)")
            loadShortcuts()
        }
    }

    @objc private func toggleEnabled(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < shortcuts.count else { return }
        let shortcut = shortcuts[row]
        let store = ConfigStore()

        // Remove old rule and add with toggled enabled
        store.removeRule(id: shortcut.id)
        let newRule = Rule(
            id: shortcut.id,
            name: shortcut.name,
            trigger: shortcut.trigger,
            actions: shortcut.actions,
            enabled: !shortcut.enabled,
            source: shortcut.source,
            scriptPath: shortcut.scriptPath
        )
        store.addRule(newRule)

        Logger.shared.log(level: .info, message: "快捷指令 \(newRule.enabled ? "启用" : "禁用"): \(shortcut.name)")
        loadShortcuts()
    }
}

extension ShortcutListWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { shortcuts.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let shortcut = shortcuts[row]
        let columnId = tableColumn?.identifier.rawValue ?? ""

        if columnId == "enabled" {
            let btn = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleEnabled(_:)))
            btn.tag = row
            btn.state = shortcut.enabled ? .on : .off
            btn.font = NSFont.systemFont(ofSize: 11)
            return btn
        }

        let cell = NSTextField(labelWithString: "")
        cell.font = NSFont.systemFont(ofSize: 13)

        if !shortcut.enabled {
            cell.textColor = NSColor.secondaryLabelColor
        }

        cell.stringValue = rowValue(shortcut, column: columnId)
        return cell
    }

    private func rowValue(_ shortcut: Rule, column: String) -> String {
        switch column {
        case "name": return shortcut.name
        case "trigger": return triggerDescription(shortcut.trigger)
        case "desc": return shortcut.scriptPath.map { "\($0.prefix(15)).js" } ?? shortcut.actions.map { $0.name }.joined(separator: ", ")
        default: return ""
        }
    }

    private func triggerDescription(_ trigger: RuleTrigger) -> String {
        switch trigger {
        case .hotkey(let key): return key
        case .wifi(let ssid): return ssid
        case .display(let count): return "\(count) 屏"
        case .time(let from, let to): return "\(from) - \(to)"
        }
    }
}
