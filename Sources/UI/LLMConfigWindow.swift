import AppKit

// MARK: - Modern LLM Config Window

class LLMConfigWindow: NSWindow {
    private var providerPopup: NSPopUpButton!
    private var modelPopup: NSPopUpButton!
    private var apiKeyField: NSTextField!
    private var apiKeyToggleBtn: NSButton!
    private var baseUrlField: NSTextField!
    private var statusLabel: NSTextField!
    private var testBtn: NSButton!
    private var saveBtn: NSButton!
    private var isKeyVisible = false

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
                   styleMask: [.titled, .closable],
                   backing: .buffered, defer: false)
        title = "LLM 配置"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 480, height: 340)
        maxSize = NSSize(width: 480, height: 340)
        center()
        backgroundColor = NSColor.windowBackgroundColor

        buildUI()
        loadConfig()
    }

    private func buildUI() {
        let w = contentView!.frame.width
        let leftX: CGFloat = 30, rightX: CGFloat = 110, width: CGFloat = w - rightX - 30
        var currentY: CGFloat = w > 0 ? 290 : 290

        func addLabel(text: String, atY: CGFloat) {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: leftX, y: atY, width: rightX - leftX - 10, height: 22)
            label.alignment = .right
            label.textColor = NSColor.secondaryLabelColor
            label.font = NSFont.systemFont(ofSize: 13)
            contentView?.addSubview(label)
        }

        // Provider
        addLabel(text: "提供商", atY: currentY)
        providerPopup = modernPopup(frame: NSRect(x: rightX, y: currentY - 2, width: width, height: 28))
        for p in LLMProvider.all { providerPopup.addItem(withTitle: p.label) }
        providerPopup.target = self
        providerPopup.action = #selector(providerChanged)
        contentView?.addSubview(providerPopup)
        currentY -= 40

        // Model
        addLabel(text: "模型", atY: currentY)
        modelPopup = modernPopup(frame: NSRect(x: rightX, y: currentY - 2, width: width, height: 28))
        contentView?.addSubview(modelPopup)
        currentY -= 40

        // API Key with toggle
        addLabel(text: "API Key", atY: currentY)
        apiKeyField = NSTextField(frame: NSRect(x: rightX, y: currentY - 2, width: width - 35, height: 28))
        apiKeyField.isBordered = true
        apiKeyField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.backgroundColor = NSColor.controlBackgroundColor
        contentView?.addSubview(apiKeyField)

        apiKeyToggleBtn = NSButton(frame: NSRect(x: rightX + width - 28, y: currentY - 2, width: 28, height: 28))
        apiKeyToggleBtn.bezelStyle = .rounded
        apiKeyToggleBtn.isBordered = false
        apiKeyToggleBtn.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "toggle")
        apiKeyToggleBtn.target = self
        apiKeyToggleBtn.action = #selector(toggleKeyVisibility)
        contentView?.addSubview(apiKeyToggleBtn)
        currentY -= 40

        // Base URL
        addLabel(text: "Base URL", atY: currentY)
        baseUrlField = NSTextField(frame: NSRect(x: rightX, y: currentY - 2, width: width, height: 28))
        baseUrlField.isBordered = true
        baseUrlField.bezelStyle = .roundedBezel
        baseUrlField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        baseUrlField.placeholderString = "留空使用默认"
        baseUrlField.backgroundColor = NSColor.controlBackgroundColor
        contentView?.addSubview(baseUrlField)
        currentY -= 55

        // Status
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: leftX, y: currentY, width: width + rightX - 10, height: 22)
        statusLabel.textColor = .systemBlue
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        contentView?.addSubview(statusLabel)
        currentY -= 30

        // Test button
        testBtn = modernButton(title: "测试连接", action: #selector(testConnection), x: leftX, width: 90)
        testBtn.frame = NSRect(x: leftX, y: currentY, width: 90, height: 30)
        contentView?.addSubview(testBtn)

        // Save button
        saveBtn = modernButton(title: "保存", action: #selector(saveConfig), x: leftX + 105, width: 60)
        saveBtn.frame = NSRect(x: leftX + 105, y: currentY, width: 60, height: 30)
        saveBtn.keyEquivalent = "\r"
        contentView?.addSubview(saveBtn)
    }

    private func modernPopup(frame: NSRect) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: frame)
        popup.font = NSFont.systemFont(ofSize: 13)
        return popup
    }

    private func modernButton(title: String, action: Selector, x: CGFloat, width: CGFloat) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .rounded
        btn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        return btn
    }

    private func loadConfig() {
        let prefs = ConfigStore()
        let config = prefs.loadLLMConfig()
        let provider = LLMProvider.byId(config.provider)

        if let idx = LLMProvider.all.firstIndex(where: { $0.id == config.provider }) {
            providerPopup.selectItem(at: idx)
        }

        updateModelPopup(models: provider.availableModels, defaultModel: config.model.isEmpty ? provider.defaultModel : config.model)

        if !config.apiKey.isEmpty {
            apiKeyField.stringValue = config.apiKey
            isKeyVisible = true
        } else {
            isKeyVisible = false
        }
        updateKeyVisibility()

        if !config.baseUrl.isEmpty {
            baseUrlField.stringValue = config.baseUrl
        }
    }

    private func updateModelPopup(models: [String], defaultModel: String) {
        modelPopup.removeAllItems()
        for m in models { modelPopup.addItem(withTitle: m) }
        if let idx = models.firstIndex(of: defaultModel) {
            modelPopup.selectItem(at: idx)
        }
    }

    @objc private func providerChanged() {
        let idx = providerPopup.indexOfSelectedItem
        let provider = LLMProvider.all[idx]
        updateModelPopup(models: provider.availableModels, defaultModel: provider.defaultModel)
        if baseUrlField.stringValue.isEmpty {
            baseUrlField.placeholderString = provider.baseUrl
        }
    }

    @objc private func toggleKeyVisibility() {
        isKeyVisible.toggle()
        updateKeyVisibility()
    }

    private func updateKeyVisibility() {
        if isKeyVisible {
            apiKeyField.isBordered = true
            apiKeyToggleBtn.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "hide")
        } else {
            apiKeyField.isBordered = true
            apiKeyToggleBtn.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "show")
            if !apiKeyField.stringValue.isEmpty {
                apiKeyField.placeholderString = String(repeating: "•", count: min(apiKeyField.stringValue.count, 20))
            }
        }
    }

    @objc private func testConnection() {
        statusLabel.stringValue = "正在测试..."
        statusLabel.textColor = .systemBlue
        testBtn.isEnabled = false

        let config = buildConfig()
        let client = LLMClient(config: config)

        Task { @MainActor in
            do {
                let ok = try await client.testConnection()
                if ok {
                    statusLabel.stringValue = "✅ 连接成功"
                    statusLabel.textColor = .systemGreen
                } else {
                    statusLabel.stringValue = "❌ 连接失败"
                    statusLabel.textColor = .systemRed
                }
            } catch {
                statusLabel.stringValue = "❌ \(error.localizedDescription)"
                statusLabel.textColor = .systemRed
            }
            testBtn.isEnabled = true
        }
    }

    @objc private func saveConfig() {
        let config = buildConfig()
        let prefs = ConfigStore()
        prefs.saveLLMConfig(config)
        statusLabel.stringValue = "✅ 已保存"
        statusLabel.textColor = .systemGreen
        Logger.shared.log(level: .info, message: "更新 LLM 配置: \(config.provider)/\(config.model)")
    }

    private func buildConfig() -> LLMConfig {
        var config = LLMConfig()
        config.provider = LLMProvider.all[providerPopup.indexOfSelectedItem].id
        config.model = modelPopup.titleOfSelectedItem ?? config.model
        config.apiKey = apiKeyField.stringValue
        config.baseUrl = baseUrlField.stringValue
        return config
    }
}
