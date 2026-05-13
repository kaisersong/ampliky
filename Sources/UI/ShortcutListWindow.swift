import AppKit

// MARK: - Shortcut List Window

class ShortcutListWindow: NSWindow {
    private var tableView: NSTableView!
    private var shortcuts: [Rule] = []

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                   styleMask: [.titled, .closable, .resizable],
                   backing: .buffered, defer: false)
        title = "快捷指令列表"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 400, height: 300)
        center()

        buildUI()
        loadShortcuts()
    }

    private func buildUI() {
        let scroll = NSScrollView(frame: contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        contentView?.addSubview(scroll)

        tableView = NSTableView(frame: scroll.bounds)
        tableView.autoresizingMask = [.width]

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "名称"
        nameCol.minWidth = 150
        nameCol.maxWidth = 200
        tableView.addTableColumn(nameCol)

        let triggerCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("trigger"))
        triggerCol.title = "触发器"
        triggerCol.minWidth = 150
        triggerCol.maxWidth = 200
        tableView.addTableColumn(triggerCol)

        let descCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("desc"))
        descCol.title = "脚本"
        descCol.minWidth = 100
        tableView.addTableColumn(descCol)

        tableView.dataSource = self
        tableView.delegate = self

        scroll.documentView = tableView
        scroll.hasVerticalScroller = true

        // Add delete button at bottom
        let toolbar = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 40))
        toolbar.autoresizingMask = [.width]

        let deleteBtn = NSButton(title: "删除选中", target: self, action: #selector(deleteSelected))
        deleteBtn.frame = NSRect(x: 10, y: 5, width: 80, height: 30)
        deleteBtn.bezelStyle = .rounded
        toolbar.addSubview(deleteBtn)

        contentView?.addSubview(toolbar)
    }

    private func loadShortcuts() {
        let store = ConfigStore()
        shortcuts = store.loadRules()
        tableView.reloadData()
    }

    @objc private func deleteSelected() {
        guard tableView.selectedRow >= 0 else { return }
        let shortcut = shortcuts[tableView.selectedRow]
        let store = ConfigStore()
        store.removeRule(id: shortcut.id)
        if let sp = shortcut.scriptPath {
            try? FileManager.default.removeItem(at: store.scriptsDir.appendingPathComponent(sp))
        }
        Logger.shared.log(level: .info, message: "删除快捷指令: \(shortcut.name)")
        loadShortcuts()
    }
}

extension ShortcutListWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        shortcuts.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let shortcut = shortcuts[row]
        let cell = NSTextField(labelWithString: "")
        cell.stringValue = rowValue(shortcut, column: tableColumn?.identifier.rawValue ?? "")
        return cell
    }

    private func rowValue(_ shortcut: Rule, column: String) -> String {
        switch column {
        case "name": return shortcut.name
        case "trigger": return triggerDescription(shortcut.trigger)
        case "desc":
            if let sp = shortcut.scriptPath {
                return "(脚本: \(sp))"
            }
            return shortcut.actions.map { "\($0.name)(\($0.params))" }.joined(separator: ", ")
        default: return ""
        }
    }

    private func triggerDescription(_ trigger: RuleTrigger) -> String {
        switch trigger {
        case .hotkey(let key): return "⌨️ \(key)"
        case .wifi(let ssid): return "📶 \(ssid)"
        case .display(let count): return "🖥 \(count) 屏"
        case .time(let from, let to): return "⏰ \(from)-\(to)"
        }
    }
}
