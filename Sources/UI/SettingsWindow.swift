import AppKit
import ServiceManagement

class SettingsWindow: NSWindow {
    private var tabBar: NSTabView!

    // LLM
    private var providerPopup: NSPopUpButton!
    private var modelPopup: NSPopUpButton!
    private var apiKeyField: NSTextField!
    private var apiKeyToggleBtn: NSButton!
    private var baseUrlField: NSTextField!
    private var llmStatusLabel: NSTextField!
    private var testBtn: NSButton!
    private var isKeyVisible = false

    // General
    private var showMenubarCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var autoUpdateCheckbox: NSButton!
    private var toggleHotkeyField: NSTextField!
    private var inputMonStatus: NSTextField!
    private var accessStatus: NSTextField!
    private var permFixBtn: NSButton!

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
                   styleMask: [.titled, .closable],
                   backing: .buffered, defer: false)
        title = "设置"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 540, height: 440)
        maxSize = NSSize(width: 540, height: 440)
        center()
        backgroundColor = NSColor.windowBackgroundColor
        level = .floating

        buildUI()
        loadSettings()
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
        makeKey()
    }

    private func buildUI() {
        let padding: CGFloat = 25
        let rightX: CGFloat = 120

        // MARK: - LLM Tab
        let llmView = NSView(frame: NSRect(x: 0, y: 0, width: contentView!.frame.width, height: contentView!.frame.height - 30))
        var y = llmView.frame.height - 35

        y = addTextField(view: llmView, label: "提供商", value: y, padding: padding, rightX: rightX) {
            self.providerPopup = NSPopUpButton(frame: $0)
            self.providerPopup.font = NSFont.systemFont(ofSize: 13)
            for p in LLMProvider.all { self.providerPopup.addItem(withTitle: p.label) }
            self.providerPopup.target = self
            self.providerPopup.action = #selector(self.providerChanged)
            llmView.addSubview(self.providerPopup)
        }
        y = addTextField(view: llmView, label: "模型", value: y, padding: padding, rightX: rightX) {
            self.modelPopup = NSPopUpButton(frame: $0)
            self.modelPopup.font = NSFont.systemFont(ofSize: 13)
            llmView.addSubview(self.modelPopup)
        }
        y = addTextField(view: llmView, label: "API Key", value: y, padding: padding, rightX: rightX) {
            self.apiKeyField = NSTextField(frame: NSRect(x: $0.origin.x, y: $0.origin.y, width: $0.width - 32, height: 28))
            self.apiKeyField.isBordered = true
            self.apiKeyField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            self.apiKeyField.placeholderString = "sk-..."
            self.apiKeyField.backgroundColor = NSColor.controlBackgroundColor
            llmView.addSubview(self.apiKeyField)

            self.apiKeyToggleBtn = NSButton(frame: NSRect(x: $0.maxX - 32, y: $0.origin.y, width: 28, height: 28))
            self.apiKeyToggleBtn.bezelStyle = .rounded
            self.apiKeyToggleBtn.isBordered = false
            self.apiKeyToggleBtn.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "toggle")
            self.apiKeyToggleBtn.target = self
            self.apiKeyToggleBtn.action = #selector(self.toggleKeyVisibility)
            llmView.addSubview(self.apiKeyToggleBtn)
        }
        y = addTextField(view: llmView, label: "Base URL", value: y, padding: padding, rightX: rightX) {
            self.baseUrlField = NSTextField(frame: $0)
            self.baseUrlField.isBordered = true
            self.baseUrlField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            self.baseUrlField.placeholderString = "留空使用默认"
            self.baseUrlField.backgroundColor = NSColor.controlBackgroundColor
            llmView.addSubview(self.baseUrlField)
        }
        y -= 45

        self.llmStatusLabel = NSTextField(labelWithString: "未配置")
        self.llmStatusLabel.frame = NSRect(x: padding, y: y, width: 200, height: 22)
        self.llmStatusLabel.textColor = .systemBlue
        self.llmStatusLabel.font = NSFont.systemFont(ofSize: 12)
        llmView.addSubview(self.llmStatusLabel)

        self.testBtn = NSButton(title: "测试连接", target: self, action: #selector(testConnection))
        self.testBtn.frame = NSRect(x: padding, y: y - 30, width: 90, height: 30)
        self.testBtn.bezelStyle = .rounded
        self.testBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        llmView.addSubview(self.testBtn)

        let llmItem = NSTabViewItem()
        llmItem.label = "LLM"
        llmItem.view = llmView

        // MARK: - General Tab
        let genView = NSView(frame: NSRect(x: 0, y: 0, width: contentView!.frame.width, height: contentView!.frame.height - 30))
        y = genView.frame.height - 35

        self.showMenubarCheckbox = NSButton(checkboxWithTitle: "显示菜单栏图标", target: self, action: nil)
        self.showMenubarCheckbox.frame = NSRect(x: padding, y: y, width: 200, height: 24)
        self.showMenubarCheckbox.font = NSFont.systemFont(ofSize: 13)
        genView.addSubview(self.showMenubarCheckbox)
        y -= 30

        self.launchAtLoginCheckbox = NSButton(checkboxWithTitle: "开机自动启动", target: self, action: nil)
        self.launchAtLoginCheckbox.frame = NSRect(x: padding, y: y, width: 200, height: 24)
        self.launchAtLoginCheckbox.font = NSFont.systemFont(ofSize: 13)
        genView.addSubview(self.launchAtLoginCheckbox)
        y -= 30

        self.autoUpdateCheckbox = NSButton(checkboxWithTitle: "自动检查更新", target: self, action: nil)
        self.autoUpdateCheckbox.frame = NSRect(x: padding, y: y, width: 200, height: 24)
        self.autoUpdateCheckbox.font = NSFont.systemFont(ofSize: 13)
        genView.addSubview(self.autoUpdateCheckbox)
        y -= 40

        let hotkeyLabel = NSTextField(labelWithString: "显示/隐藏图标快捷键:")
        hotkeyLabel.frame = NSRect(x: padding, y: y, width: 200, height: 22)
        hotkeyLabel.font = NSFont.systemFont(ofSize: 13)
        genView.addSubview(hotkeyLabel)
        y -= 25

        self.toggleHotkeyField = NSTextField(frame: NSRect(x: padding, y: y, width: 200, height: 28))
        self.toggleHotkeyField.isBordered = true
        self.toggleHotkeyField.isEditable = false
        self.toggleHotkeyField.backgroundColor = NSColor.controlBackgroundColor
        self.toggleHotkeyField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        self.toggleHotkeyField.alignment = .center
        genView.addSubview(self.toggleHotkeyField)
        y -= 50

        let permLabel = NSTextField(labelWithString: "系统权限")
        permLabel.frame = NSRect(x: padding, y: y, width: 200, height: 22)
        permLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        genView.addSubview(permLabel)
        y -= 25

        self.inputMonStatus = NSTextField(labelWithString: "")
        self.inputMonStatus.frame = NSRect(x: padding, y: y, width: 280, height: 22)
        self.inputMonStatus.font = NSFont.systemFont(ofSize: 13)
        genView.addSubview(self.inputMonStatus)
        y -= 25

        self.accessStatus = NSTextField(labelWithString: "")
        self.accessStatus.frame = NSRect(x: padding, y: y, width: 280, height: 22)
        self.accessStatus.font = NSFont.systemFont(ofSize: 13)
        genView.addSubview(self.accessStatus)
        y -= 30

        self.permFixBtn = NSButton(title: "去设置", target: self, action: #selector(openPermissionSettings))
        self.permFixBtn.frame = NSRect(x: padding, y: y, width: 60, height: 28)
        self.permFixBtn.bezelStyle = .rounded
        self.permFixBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        genView.addSubview(self.permFixBtn)

        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let versionLabel = NSTextField(labelWithString: "Ampliky \(version) (\(build))")
        versionLabel.frame = NSRect(x: padding, y: 10, width: 300, height: 20)
        versionLabel.textColor = NSColor.tertiaryLabelColor
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        genView.addSubview(versionLabel)

        let genItem = NSTabViewItem()
        genItem.label = "通用"
        genItem.view = genView

        tabBar = NSTabView(frame: contentView!.bounds)
        tabBar.addTabViewItem(llmItem)
        tabBar.addTabViewItem(genItem)
        contentView?.addSubview(tabBar)
    }

    private func addTextField(view: NSView, label: String, value y: CGFloat, padding: CGFloat, rightX: CGFloat, setup: (NSRect) -> Void) -> CGFloat {
        let labelField = NSTextField(labelWithString: label)
        labelField.frame = NSRect(x: padding, y: y, width: rightX - padding - 10, height: 22)
        labelField.alignment = .right
        labelField.textColor = NSColor.secondaryLabelColor
        labelField.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(labelField)

        let fieldRect = NSRect(x: rightX, y: y - 2, width: view.frame.width - rightX - padding, height: 28)
        setup(fieldRect)
        return y - 40
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
        apiKeyToggleBtn.image = NSImage(systemSymbolName: isKeyVisible ? "eye" : "eye.slash", accessibilityDescription: "toggle")
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
        let config = prefs.loadLLMConfig()
        let provider = LLMProvider.byId(config.provider)

        if let idx = LLMProvider.all.firstIndex(where: { $0.id == config.provider }) {
            providerPopup.selectItem(at: idx)
        }
        updateModelPopup(models: provider.availableModels, defaultModel: config.model.isEmpty ? provider.defaultModel : config.model)

        if !config.apiKey.isEmpty {
            apiKeyField.stringValue = config.apiKey
            isKeyVisible = true
        }
        if !config.baseUrl.isEmpty { baseUrlField.stringValue = config.baseUrl }

        showMenubarCheckbox?.state = prefs.shouldShowMenubar() ? .on : .off
        launchAtLoginCheckbox?.state = LaunchAtLogin.isEnabled ? .on : .off
        autoUpdateCheckbox?.state = prefs.shouldAutoUpdate() ? .on : .off
        toggleHotkeyField?.stringValue = prefs.getToggleMenubarHotkey()

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
