import AppKit
import ServiceManagement

// MARK: - Unified Settings Window

class SettingsWindow: NSWindow {
    private var tabBar: NSTabView!
    private var llmSection: NSView!
    private var generalSection: NSView!

    // LLM fields
    private var providerPopup: NSPopUpButton!
    private var modelPopup: NSPopUpButton!
    private var apiKeyField: NSTextField!
    private var apiKeyToggleBtn: NSButton!
    private var baseUrlField: NSTextField!
    private var llmStatusLabel: NSTextField!
    private var testBtn: NSButton!
    private var isKeyVisible = false

    // General fields
    private var showMenubarCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var autoUpdateCheckbox: NSButton!
    private var toggleHotkeyField: NSTextField!

    // Permission status
    private var inputMonStatus: NSTextField!
    private var accessStatus: NSTextField!
    private var permFixBtn: NSButton!

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 520, height: 450),
                   styleMask: [.titled, .closable],
                   backing: .buffered, defer: false)
        title = "设置"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 520, height: 450)
        maxSize = NSSize(width: 520, height: 450)
        center()
        backgroundColor = NSColor.windowBackgroundColor

        buildUI()
        loadSettings()
    }

    private func buildUI() {
        tabBar = NSTabView(frame: contentView!.bounds)
        tabBar.autoresizingMask = [.width, .height]

        llmSection = buildLLMSection()
        let llmItem = NSTabViewItem(identifier: NSUserInterfaceItemIdentifier("llm"))
        llmItem.label = "LLM"
        llmItem.view = llmSection
        tabBar.addTabViewItem(llmItem)

        generalSection = buildGeneralSection()
        let generalItem = NSTabViewItem(identifier: NSUserInterfaceItemIdentifier("general"))
        generalItem.label = "通用"
        generalItem.view = generalSection
        tabBar.addTabViewItem(generalItem)

        contentView?.addSubview(tabBar)
    }

    // MARK: - LLM Section

    private func buildLLMSection() -> NSView {
        let view = NSView(frame: tabBar.bounds)
        let leftX: CGFloat = 30, rightX: CGFloat = 110
        let width: CGFloat = view.frame.width - rightX - 30
        var y: CGFloat = view.frame.height - 35

        func addLabel(text: String, atY: CGFloat) {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: leftX, y: atY, width: rightX - leftX - 10, height: 22)
            label.alignment = .right
            label.textColor = NSColor.secondaryLabelColor
            label.font = NSFont.systemFont(ofSize: 13)
            view.addSubview(label)
        }

        // Provider
        addLabel(text: "提供商", atY: y)
        providerPopup = NSPopUpButton(frame: NSRect(x: rightX, y: y - 2, width: width, height: 28))
        providerPopup.font = NSFont.systemFont(ofSize: 13)
        for p in LLMProvider.all { providerPopup.addItem(withTitle: p.label) }
        providerPopup.target = self
        providerPopup.action = #selector(providerChanged)
        view.addSubview(providerPopup)
        y -= 40

        // Model
        addLabel(text: "模型", atY: y)
        modelPopup = NSPopUpButton(frame: NSRect(x: rightX, y: y - 2, width: width, height: 28))
        modelPopup.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(modelPopup)
        y -= 40

        // API Key
        addLabel(text: "API Key", atY: y)
        apiKeyField = NSTextField(frame: NSRect(x: rightX, y: y - 2, width: width - 35, height: 28))
        apiKeyField.isBordered = true
        apiKeyField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.backgroundColor = NSColor.controlBackgroundColor
        view.addSubview(apiKeyField)

        apiKeyToggleBtn = NSButton(frame: NSRect(x: rightX + width - 28, y: y - 2, width: 28, height: 28))
        apiKeyToggleBtn.bezelStyle = .rounded
        apiKeyToggleBtn.isBordered = false
        apiKeyToggleBtn.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "toggle")
        apiKeyToggleBtn.target = self
        apiKeyToggleBtn.action = #selector(toggleKeyVisibility)
        view.addSubview(apiKeyToggleBtn)
        y -= 40

        // Base URL
        addLabel(text: "Base URL", atY: y)
        baseUrlField = NSTextField(frame: NSRect(x: rightX, y: y - 2, width: width, height: 28))
        baseUrlField.isBordered = true
        baseUrlField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        baseUrlField.placeholderString = "留空使用默认"
        baseUrlField.backgroundColor = NSColor.controlBackgroundColor
        view.addSubview(baseUrlField)
        y -= 55

        // Status
        llmStatusLabel = NSTextField(labelWithString: "未配置")
        llmStatusLabel.frame = NSRect(x: leftX, y: y, width: width + rightX - 10, height: 22)
        llmStatusLabel.textColor = .systemBlue
        llmStatusLabel.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(llmStatusLabel)
        y -= 30

        // Test button
        testBtn = NSButton(title: "测试连接", target: self, action: #selector(testConnection))
        testBtn.frame = NSRect(x: leftX, y: y, width: 90, height: 30)
        testBtn.bezelStyle = .rounded
        testBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        view.addSubview(testBtn)

        return view
    }

    // MARK: - General Section

    private func buildGeneralSection() -> NSView {
        let view = NSView(frame: tabBar.bounds)
        let leftX: CGFloat = 30
        var y: CGFloat = view.frame.height - 35

        func addCheckbox(text: String, atY: CGFloat) -> NSButton {
            let cb = NSButton(checkboxWithTitle: text, target: self, action: nil)
            cb.frame = NSRect(x: leftX, y: atY, width: 300, height: 24)
            cb.font = NSFont.systemFont(ofSize: 13)
            view.addSubview(cb)
            return cb
        }

        showMenubarCheckbox = addCheckbox(text: "显示菜单栏图标", atY: y)
        y -= 30

        launchAtLoginCheckbox = addCheckbox(text: "开机自动启动", atY: y)
        y -= 30

        autoUpdateCheckbox = addCheckbox(text: "自动检查更新", atY: y)
        y -= 45

        // Toggle hotkey
        let hotkeyLabel = NSTextField(labelWithString: "显示/隐藏图标快捷键:")
        hotkeyLabel.frame = NSRect(x: leftX, y: y, width: 200, height: 22)
        hotkeyLabel.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(hotkeyLabel)
        y -= 25

        toggleHotkeyField = NSTextField(frame: NSRect(x: leftX, y: y, width: 200, height: 28))
        toggleHotkeyField.isBordered = true
        toggleHotkeyField.isEditable = false
        toggleHotkeyField.backgroundColor = NSColor.controlBackgroundColor
        toggleHotkeyField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        toggleHotkeyField.alignment = .center
        view.addSubview(toggleHotkeyField)
        y -= 50

        // Permission status section
        let permLabel = NSTextField(labelWithString: "系统权限")
        permLabel.frame = NSRect(x: leftX, y: y, width: 200, height: 22)
        permLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        view.addSubview(permLabel)
        y -= 25

        inputMonStatus = NSTextField(labelWithString: "")
        inputMonStatus.frame = NSRect(x: leftX, y: y, width: 250, height: 22)
        inputMonStatus.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(inputMonStatus)
        y -= 25

        accessStatus = NSTextField(labelWithString: "")
        accessStatus.frame = NSRect(x: leftX, y: y, width: 250, height: 22)
        accessStatus.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(accessStatus)
        y -= 30

        permFixBtn = NSButton(title: "去设置", target: self, action: #selector(openPermissionSettings))
        permFixBtn.frame = NSRect(x: leftX, y: y, width: 60, height: 28)
        permFixBtn.bezelStyle = .rounded
        permFixBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        view.addSubview(permFixBtn)

        // Version info
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "0"

        let versionLabel = NSTextField(labelWithString: "Ampliky \(version) (\(build))")
        versionLabel.frame = NSRect(x: leftX, y: 10, width: 300, height: 20)
        versionLabel.textColor = NSColor.tertiaryLabelColor
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(versionLabel)

        return view
    }

    // MARK: - Actions

    @objc private func providerChanged() {
        let idx = providerPopup.indexOfSelectedItem
        let provider = LLMProvider.all[idx]
        updateModelPopup(models: provider.availableModels, defaultModel: provider.defaultModel)
        if baseUrlField.stringValue.isEmpty {
            baseUrlField.placeholderString = provider.baseUrl
        }
    }

    private func updateModelPopup(models: [String], defaultModel: String) {
        modelPopup.removeAllItems()
        for m in models { modelPopup.addItem(withTitle: m) }
        if let idx = models.firstIndex(of: defaultModel) {
            modelPopup.selectItem(at: idx)
        }
    }

    @objc private func toggleKeyVisibility() {
        isKeyVisible.toggle()
        if isKeyVisible {
            apiKeyToggleBtn.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "hide")
        } else {
            apiKeyToggleBtn.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "show")
        }
    }

    @objc private func testConnection() {
        llmStatusLabel.stringValue = "正在测试..."
        llmStatusLabel.textColor = .systemBlue
        testBtn.isEnabled = false

        let config = buildLLMConfig()
        let client = LLMClient(config: config)

        Task { @MainActor in
            do {
                let ok = try await client.testConnection()
                if ok {
                    llmStatusLabel.stringValue = "✅ 连接成功"
                    llmStatusLabel.textColor = .systemGreen
                } else {
                    llmStatusLabel.stringValue = "❌ 连接失败"
                    llmStatusLabel.textColor = .systemRed
                }
            } catch {
                llmStatusLabel.stringValue = "❌ \(error.localizedDescription)"
                llmStatusLabel.textColor = .systemRed
            }
            testBtn.isEnabled = true
        }
    }

    @objc private func openPermissionSettings() {
        PermissionChecker.requestInputMonitoring()
        PermissionChecker.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    private func loadSettings() {
        let prefs = ConfigStore()

        // LLM
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
        if !config.baseUrl.isEmpty { baseUrlField.stringValue = config.baseUrl }

        // General
        showMenubarCheckbox?.state = prefs.shouldShowMenubar() ? .on : .off
        launchAtLoginCheckbox?.state = LaunchAtLogin.isEnabled ? .on : .off
        autoUpdateCheckbox?.state = prefs.shouldAutoUpdate() ? .on : .off
        toggleHotkeyField?.stringValue = prefs.getToggleMenubarHotkey()

        // Permissions
        updatePermissionStatus()
    }

    private func updatePermissionStatus() {
        let hasInput = PermissionChecker.hasInputMonitoringPermission()
        let hasAccess = PermissionChecker.hasAccessibilityPermission()

        inputMonStatus.stringValue = hasInput ? "✅ 输入监控 — 已授权" : "❌ 输入监控 — 未授权"
        inputMonStatus.textColor = hasInput ? .systemGreen : .systemRed

        accessStatus.stringValue = hasAccess ? "✅ 辅助功能 — 已授权" : "❌ 辅助功能 — 未授权"
        accessStatus.textColor = hasAccess ? .systemGreen : .systemRed

        permFixBtn.isHidden = hasInput && hasAccess
    }

    func save() {
        let prefs = ConfigStore()
        prefs.saveLLMConfig(buildLLMConfig())
        prefs.setShowMenubar(showMenubarCheckbox?.state == .on)
        LaunchAtLogin.isEnabled = launchAtLoginCheckbox?.state == .on
        prefs.setAutoUpdate(autoUpdateCheckbox?.state == .on)
        Logger.shared.log(level: .info, message: "保存设置")
        updatePermissionStatus()
    }

    private func buildLLMConfig() -> LLMConfig {
        var config = LLMConfig()
        config.provider = LLMProvider.all[providerPopup.indexOfSelectedItem].id
        config.model = modelPopup.titleOfSelectedItem ?? config.model
        config.apiKey = apiKeyField.stringValue
        config.baseUrl = baseUrlField.stringValue
        return config
    }
}

// MARK: - Launch at Login

enum LaunchAtLogin {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            try? SMAppService.mainApp.unregister()
            if newValue { try? SMAppService.mainApp.register() }
        }
    }
}
