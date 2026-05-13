import AppKit

// MARK: - Log Window

class LogWindow: NSWindow {
    private var tableView: NSTableView!
    private var clearBtn: NSButton!

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 650, height: 400),
                   styleMask: [.titled, .closable, .resizable],
                   backing: .buffered, defer: false)
        title = "运行日志"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 400, height: 250)
        center()

        buildUI()
        loadLogs()
    }

    private func buildUI() {
        let scroll = NSScrollView(frame: contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        contentView?.addSubview(scroll)

        tableView = NSTableView(frame: scroll.bounds)
        tableView.autoresizingMask = [.width]

        // Time column
        let timeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeCol.title = "时间"
        timeCol.minWidth = 140
        timeCol.maxWidth = 160
        tableView.addTableColumn(timeCol)

        // Level column
        let levelCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("level"))
        levelCol.title = "级别"
        levelCol.minWidth = 50
        levelCol.maxWidth = 70
        tableView.addTableColumn(levelCol)

        // Message column
        let msgCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("message"))
        msgCol.title = "消息"
        msgCol.minWidth = 200
        tableView.addTableColumn(msgCol)

        tableView.dataSource = self
        tableView.delegate = self
        scroll.documentView = tableView

        // Clear button
        clearBtn = NSButton(title: "清空日志", target: self, action: #selector(clearLogs))
        clearBtn.frame = NSRect(x: 15, y: 10, width: 80, height: 25)
        clearBtn.bezelStyle = .rounded
        clearBtn.autoresizingMask = [.minYMargin]
        contentView?.addSubview(clearBtn)
    }

    private func loadLogs() {
        tableView.reloadData()
    }

    @objc private func clearLogs() {
        Logger.shared.clear()
        tableView.reloadData()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

extension LogWindow: NSTableViewDataSource, NSTableViewDelegate {
    var entries: [LogEntry] { Logger.shared.entries }

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = entries[entries.count - 1 - row] // Newest first
        let cell = NSTextField(labelWithString: "")
        cell.font = NSFont.systemFont(ofSize: 12)

        switch tableColumn?.identifier.rawValue ?? "" {
        case "time":
            cell.stringValue = formatTime(entry.timestamp)
        case "level":
            cell.stringValue = entry.level.rawValue
            cell.textColor = entry.level == .error ? .systemRed : .systemGreen
        case "message":
            cell.stringValue = entry.message
        default:
            cell.stringValue = ""
        }

        return cell
    }
}
