import AppKit

// MARK: - LLM Config Window

class LLMConfigWindow: NSWindow {
    private var providerPopup: NSPopUpButton!
    private var modelPopup: NSPopUpButton!
    private var apiKeyField: NSSecureTextField!
    private var baseUrlField: NSTextField!
    private var statusLabel: NSTextField!
    private var testBtn: NSButton!
    private var saveBtn: NSButton!

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 450, height: 320),
                   styleMask: [.titled, .closable],
                   backing: .buffered, defer: false)
        title = "LLM 配置"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 450, height: 320)
        maxSize = NSSize(width: 450, height: 320)
        center()

        buildUI()
        loadConfig()
    }

    private func buildUI() {
        let y = contentView!.frame.height
        let leftX: CGFloat = 20, rightX: CGFloat = 160, width: CGFloat = 260
        var currentY = y - 40

        func addLabel(text: String, atY: CGFloat) {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: leftX, y: atY, width: rightX - leftX - 10, height: 24)
            label.alignment = .right
            contentView?.addSubview(label)
        }

        // Provider
        addLabel(text: "提供商:", atY: currentY)
        providerPopup = NSPopUpButton(frame: NSRect(x: rightX, y: currentY - 3, width: width, height: 30))
        for p in LLMProvider.all { providerPopup.addItem(withTitle: p.label) }
        providerPopup.target = self
        providerPopup.action = #selector(providerChanged)
        contentView?.addSubview(providerPopup)
        currentY -= 40

        // Model
        addLabel(text: "模型:", atY: currentY)
        modelPopup = NSPopUpButton(frame: NSRect(x: rightX, y: currentY - 3, width: width, height: 30))
        contentView?.addSubview(modelPopup)
        currentY -= 40

        // API Key
        addLabel(text: "API Key:", atY: currentY)
        apiKeyField = NSSecureTextField(frame: NSRect(x: rightX, y: currentY - 3, width: width, height: 30))
        apiKeyField.placeholderString = "sk-..."
        contentView?.addSubview(apiKeyField)
        currentY -= 40

        // Base URL
        addLabel(text: "Base URL:", atY: currentY)
        baseUrlField = NSTextField(frame: NSRect(x: rightX, y: currentY - 3, width: width, height: 30))
        baseUrlField.placeholderString = "留空使用默认"
        contentView?.addSubview(baseUrlField)
        currentY -= 50

        // Status
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: leftX, y: currentY, width: width + rightX, height: 24)
        statusLabel.textColor = .systemBlue
        contentView?.addSubview(statusLabel)
        currentY -= 35

        // Test button
        testBtn = NSButton(title: "测试连接", target: self, action: #selector(testConnection))
        testBtn.frame = NSRect(x: leftX, y: currentY, width: 80, height: 30)
        testBtn.bezelStyle = .rounded
        contentView?.addSubview(testBtn)

        // Save button
        saveBtn = NSButton(title: "保存", target: self, action: #selector(saveConfig))
        saveBtn.frame = NSRect(x: leftX + 100, y: currentY, width: 60, height: 30)
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        contentView?.addSubview(saveBtn)
    }

    private func loadConfig() {
        let prefs = ConfigStore()
        let config = prefs.loadLLMConfig()
        let provider = LLMProvider.byId(config.provider)

        // Set provider
        if let idx = LLMProvider.all.firstIndex(where: { $0.id == config.provider }) {
            providerPopup.selectItem(at: idx)
        }

        // Set models
        updateModelPopup(models: provider.availableModels, defaultModel: config.model.isEmpty ? provider.defaultModel : config.model)

        // Set API key
        if !config.apiKey.isEmpty {
            apiKeyField.stringValue = config.apiKey
        }

        // Set base URL
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
