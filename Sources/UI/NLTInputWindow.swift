import AppKit

class NLTInputWindow: NSWindow {
    private var inputView: NSTextView!
    private var generateBtn: NSButton!
    private var triggerLabel: NSTextField!
    private var scriptView: NSTextView!
    private var statusLabel: NSTextField!
    private var saveBtn: NSButton!
    private var cancelBtn: NSButton!

    private var lastParsedResult: (trigger: RuleTrigger, script: String)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
                   styleMask: [.titled, .closable, .resizable],
                   backing: .buffered, defer: false)
        title = "新建快捷指令"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 400, height: 350)
        center()
        buildUI()
    }

    private func buildUI() {
        let w = contentView!.frame.width
        var currentY: CGFloat = contentView!.frame.height - 30

        let descLabel = NSTextField(labelWithString: "描述你的需求：")
        descLabel.frame = NSRect(x: 15, y: currentY - 20, width: 200, height: 20)
        contentView?.addSubview(descLabel)
        currentY -= 40

        let scroll = NSScrollView(frame: NSRect(x: 15, y: currentY - 60, width: w - 30, height: 60))
        scroll.hasVerticalScroller = true
        inputView = NSTextView(frame: scroll.bounds)
        inputView.autoresizingMask = [.width]
        inputView.isRichText = false
        inputView.font = NSFont.systemFont(ofSize: 13)
        inputView.string = "三指点击跳到右边的屏幕"
        scroll.documentView = inputView
        contentView?.addSubview(scroll)
        currentY -= 75

        generateBtn = NSButton(title: "生成快捷指令", target: self, action: #selector(generate))
        generateBtn.frame = NSRect(x: 15, y: currentY - 30, width: 120, height: 30)
        generateBtn.bezelStyle = .rounded
        generateBtn.keyEquivalent = "\r"
        contentView?.addSubview(generateBtn)
        currentY -= 40

        let previewLabel = NSTextField(labelWithString: "── 预览 ──")
        previewLabel.frame = NSRect(x: 15, y: currentY - 15, width: 200, height: 20)
        contentView?.addSubview(previewLabel)
        currentY -= 30

        triggerLabel = NSTextField(labelWithString: "触发器: 等待生成...")
        triggerLabel.frame = NSRect(x: 15, y: currentY - 15, width: w - 30, height: 20)
        triggerLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        contentView?.addSubview(triggerLabel)
        currentY -= 25

        let scriptScroll = NSScrollView(frame: NSRect(x: 15, y: currentY - 80, width: w - 30, height: 80))
        scriptScroll.hasVerticalScroller = true
        scriptView = NSTextView(frame: scriptScroll.bounds)
        scriptView.autoresizingMask = [.width]
        scriptView.isRichText = false
        scriptView.isEditable = false
        scriptView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        scriptView.backgroundColor = NSColor.controlBackgroundColor
        scriptScroll.documentView = scriptView
        contentView?.addSubview(scriptScroll)
        currentY -= 95

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 15, y: currentY - 15, width: w - 30, height: 20)
        statusLabel.textColor = .systemBlue
        contentView?.addSubview(statusLabel)
        currentY -= 30

        saveBtn = NSButton(title: "保存", target: self, action: #selector(save))
        saveBtn.frame = NSRect(x: 15, y: currentY - 30, width: 60, height: 30)
        saveBtn.bezelStyle = .rounded
        saveBtn.isEnabled = false
        contentView?.addSubview(saveBtn)

        cancelBtn = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelBtn.frame = NSRect(x: 85, y: currentY - 30, width: 60, height: 30)
        cancelBtn.bezelStyle = .rounded
        contentView?.addSubview(cancelBtn)
    }

    @objc private func generate() {
        let intent = inputView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !intent.isEmpty else { return }

        let prefs = ConfigStore()
        let llmConfig = prefs.loadLLMConfig()

        guard !llmConfig.apiKey.isEmpty else {
            statusLabel.stringValue = "请先配置 LLM（点击设置）"
            statusLabel.textColor = .systemRed
            return
        }

        statusLabel.stringValue = "正在生成..."
        statusLabel.textColor = .systemBlue
        generateBtn.isEnabled = false

        let systemPrompt = SystemPrompt.build(intent: intent, context: "screens: \(NSScreen.screens.count)")

        Task { @MainActor in
            let client = LLMClient(config: llmConfig)
            do {
                let response = try await client.chat(system: systemPrompt, user: intent)
                print("[Ampliky] LLM response:\n\(response)")

                if let result = parseLLMResponse(response) {
                    lastParsedResult = result
                    triggerLabel.stringValue = "触发器: \(triggerDescription(result.trigger))"
                    scriptView.string = result.script
                    saveBtn.isEnabled = true
                    statusLabel.stringValue = "✅ 生成成功，可以预览后保存"
                    statusLabel.textColor = .systemGreen
                    Logger.shared.log(level: .info, message: "生成快捷指令: \(intent)")
                } else {
                    // Show raw response for debugging
                    scriptView.string = response
                    statusLabel.stringValue = "❌ LLM 返回格式不正确"
                    statusLabel.textColor = .systemRed
                }
            } catch {
                statusLabel.stringValue = "❌ \(error.localizedDescription)"
                statusLabel.textColor = .systemRed
            }
            generateBtn.isEnabled = true
        }
    }

    @objc private func save() {
        let intent = inputView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let result = lastParsedResult else { return }

        let scriptStore = ScriptStore()
        let filename = scriptStore.saveScript(content: result.script, name: intent)

        let store = ConfigStore()
        let shortcut = Rule(
            id: UUID().uuidString,
            name: intent,
            trigger: result.trigger,
            actions: [],
            enabled: true,
            source: "ai",
            scriptPath: filename
        )
        store.addRule(shortcut)

        Logger.shared.log(level: .info, message: "保存快捷指令: \(intent)")
        statusLabel.stringValue = "✅ 已保存"
        statusLabel.textColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.close()
        }
    }

    @objc private func cancel() {
        close()
    }

    private func parseLLMResponse(_ response: String) -> (trigger: RuleTrigger, script: String)? {
        // Step 1: Extract JSON from markdown code blocks or raw text
        var jsonStr = response

        // Try markdown code block first
        if let start = response.range(of: "```json"),
           let afterStart = response.index(start.upperBound, offsetBy: 1, limitedBy: response.endIndex),
           let end = response.range(of: "```", range: afterStart..<response.endIndex) {
            jsonStr = String(response[afterStart..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let start = response.range(of: "```"),
                  let afterStart = response.index(start.upperBound, offsetBy: 1, limitedBy: response.endIndex),
                  let end = response.range(of: "```", range: afterStart..<response.endIndex) {
            jsonStr = String(response[afterStart..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Fallback: find outermost {...}
            if let start = response.range(of: "{"),
               let end = response.range(of: "}", options: .backwards) {
                jsonStr = String(response[start.lowerBound..<end.upperBound])
            }
        }

        print("[Ampliky] Extracted JSON: \(jsonStr)")

        // Step 2: Parse JSON
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[Ampliky] JSON parse failed")
            return nil
        }

        // Step 3: Extract trigger
        guard let triggerObj = json["trigger"] as? [String: Any],
              let triggerType = triggerObj["type"] as? String else {
            print("[Ampliky] Missing trigger in JSON")
            return nil
        }

        let trigger: RuleTrigger
        switch triggerType {
        case "hotkey":
            guard let key = triggerObj["key"] as? String else { return nil }
            trigger = .hotkey(key: key)
        case "wifi":
            guard let ssid = triggerObj["ssid"] as? String else { return nil }
            trigger = .wifi(ssid: ssid)
        case "display":
            guard let count = triggerObj["count"] as? Int else { return nil }
            trigger = .display(count: count)
        case "time":
            guard let from = triggerObj["from"] as? String,
                  let to = triggerObj["to"] as? String else { return nil }
            trigger = .time(from: from, to: to)
        default:
            // Fallback: if LLM returned an unknown trigger type, default to hotkey
            // This ensures we always get a valid shortcut even if LLM is creative
            if let key = triggerObj["key"] as? String {
                trigger = .hotkey(key: key)
            } else {
                trigger = .hotkey(key: "cmd+opt+g")
            }
        }

        // Step 4: Extract script
        guard let script = json["script"] as? String, !script.isEmpty else {
            print("[Ampliky] Missing script in JSON")
            return nil
        }

        return (trigger, script)
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
