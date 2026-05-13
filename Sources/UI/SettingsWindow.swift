import AppKit
import ServiceManagement

class SettingsWindowController: NSWindowController {

    private var containerView: NSView!
    private var tabBar: NSView!
    private var tabButtons: [NSButton] = []
    private var tabContents: [NSView] = []
    private var currentTab = 0

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
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        win.title = "设置"
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 540, height: 440)
        win.maxSize = NSSize(width: 540, height: 440)
        win.center()
        win.backgroundColor = NSColor.windowBackgroundColor
        super.init(window: win)

        buildUI()
        loadSettings()

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(providerPopup)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 440))

        // Tab bar
        tabBar = NSView(frame: NSRect(x: 0, y: 390, width: 540, height: 50))
        tabBar.wantsLayer = true
        tabBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        containerView.addSubview(tabBar)

        let tabNames = ["LLM", "通用"]
        for (i, name) in tabNames.enumerated() {
            let btn = NSButton(title: name, target: self, action: #selector(switchTab(_:)))
            btn.frame = NSRect(x: 20 + CGFloat(i) * 70, y: 10, width: 60, height: 30)
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            btn.tag = i
            btn.state = i == 0 ? .on : .off
            tabBar.addSubview(btn)
            tabButtons.append(btn)
        }

        // LLM content
        tabContents.append(buildLLMView())
        // General content
        tabContents.append(buildGeneralView())

        containerView.addSubview(tabContents[0])
        containerView.addSubview(tabContents[1])
        tabContents[1].isHidden = true

        window?.contentView = containerView
    }

    @objc private func switchTab(_ sender: NSButton) {
        tabContents[currentTab].isHidden = true
        tabButtons[currentTab].state = .off
        currentTab = sender.tag
        tabContents[currentTab].isHidden = false
        tabButtons[currentTab].state = .on
    }

    // MARK: - LLM View

    private func buildLLMView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 390))
        let padding: CGFloat = 30, rightX: CGFloat = 110
        let fw = view.frame.width - rightX - padding
        var y: CGFloat = view.frame.height - 25

        func addLabel(_ text: String) {
            let l = NSTextField(labelWithString: text)
            l.frame = NSRect(x: padding, y: y, width: rightX - padding - 10, height: 22)
            l.alignment = .right; l.textColor = NSColor.secondaryLabelColor; l.font = NSFont.systemFont(ofSize: 13)
            view.addSubview(l)
        }

        addLabel("提供商")
        providerPopup = NSPopUpButton(frame: NSRect(x: rightX, y: y - 2, width: fw, height: 28))
        providerPopup.font = NSFont.systemFont(ofSize: 13)
        for p in LLMProvider.all { providerPopup.addItem(withTitle: p.label) }
        providerPopup.target = self; providerPopup.action = #selector(providerChanged)
        view.addSubview(providerPopup); y -= 40

        addLabel("模型")
        modelPopup = NSPopUpButton(frame: NSRect(x: rightX, y: y - 2, width: fw, height: 28))
        modelPopup.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(modelPopup); y -= 40

        addLabel("API Key")
        apiKeyField = NSTextField(frame: NSRect(x: rightX, y: y - 2, width: fw - 32, height: 28))
        apiKeyField.isBordered = true; apiKeyField.isEditable = true; apiKeyField.isSelectable = true
        apiKeyField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.backgroundColor = NSColor.controlBackgroundColor
        view.addSubview(apiKeyField)

        apiKeyToggleBtn = NSButton(frame: NSRect(x: rightX + fw - 28, y: y - 2, width: 28, height: 28))
        apiKeyToggleBtn.bezelStyle = .rounded; apiKeyToggleBtn.isBordered = false
        apiKeyToggleBtn.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "")
        apiKeyToggleBtn.target = self; apiKeyToggleBtn.action = #selector(toggleKeyVisibility)
        view.addSubview(apiKeyToggleBtn); y -= 40

        addLabel("Base URL")
        baseUrlField = NSTextField(frame: NSRect(x: rightX, y: y - 2, width: fw, height: 28))
        baseUrlField.isBordered = true; baseUrlField.isEditable = true; baseUrlField.isSelectable = true
        baseUrlField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        baseUrlField.placeholderString = "留空使用默认"
        baseUrlField.backgroundColor = NSColor.controlBackgroundColor
        view.addSubview(baseUrlField); y -= 55

        llmStatusLabel = NSTextField(labelWithString: "未配置")
        llmStatusLabel.frame = NSRect(x: padding, y: y, width: 200, height: 22)
        llmStatusLabel.textColor = .systemBlue; llmStatusLabel.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(llmStatusLabel)

        testBtn = NSButton(title: "测试连接", target: self, action: #selector(testConnection))
        testBtn.frame = NSRect(x: padding, y: y - 30, width: 90, height: 30)
        testBtn.bezelStyle = .rounded; testBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        view.addSubview(testBtn)

        return view
    }

    // MARK: - General View

    private func buildGeneralView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 390))
        let padding: CGFloat = 30
        var y: CGFloat = view.frame.height - 25

        func addCheckbox(_ text: String) -> NSButton {
            let cb = NSButton(checkboxWithTitle: text, target: nil, action: nil)
            cb.frame = NSRect(x: padding, y: y, width: 200, height: 24)
            cb.font = NSFont.systemFont(ofSize: 13)
            view.addSubview(cb); y -= 30; return cb
        }

        showMenubarCheckbox = addCheckbox("显示菜单栏图标")
        launchAtLoginCheckbox = addCheckbox("开机自动启动")
        autoUpdateCheckbox = addCheckbox("自动检查更新")
        y -= 10

        let hl = NSTextField(labelWithString: "显示/隐藏图标快捷键:")
        hl.frame = NSRect(x: padding, y: y, width: 200, height: 22); hl.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(hl); y -= 25

        toggleHotkeyField = NSTextField(frame: NSRect(x: padding, y: y, width: 200, height: 28))
        toggleHotkeyField.isBordered = true; toggleHotkeyField.isEditable = false
        toggleHotkeyField.backgroundColor = NSColor.controlBackgroundColor
        toggleHotkeyField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        toggleHotkeyField.alignment = .center
        view.addSubview(toggleHotkeyField); y -= 50

        let pl = NSTextField(labelWithString: "系统权限")
        pl.frame = NSRect(x: padding, y: y, width: 200, height: 22)
        pl.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        view.addSubview(pl); y -= 25

        inputMonStatus = NSTextField(labelWithString: "")
        inputMonStatus.frame = NSRect(x: padding, y: y, width: 280, height: 22)
        inputMonStatus.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(inputMonStatus); y -= 25

        accessStatus = NSTextField(labelWithString: "")
        accessStatus.frame = NSRect(x: padding, y: y, width: 280, height: 22)
        accessStatus.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(accessStatus); y -= 30

        permFixBtn = NSButton(title: "去设置", target: self, action: #selector(openPermissionSettings))
        permFixBtn.frame = NSRect(x: padding, y: y, width: 60, height: 28)
        permFixBtn.bezelStyle = .rounded; permFixBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        view.addSubview(permFixBtn)

        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let vl = NSTextField(labelWithString: "Ampliky \(version) (\(build))")
        vl.frame = NSRect(x: padding, y: 10, width: 300, height: 20)
        vl.textColor = NSColor.tertiaryLabelColor; vl.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(vl)

        return view
    }

    // MARK: - Actions

    @objc private func providerChanged() {
        let idx = providerPopup.indexOfSelectedItem
        let provider = LLMProvider.all[idx]
        updateModelPopup(models: provider.availableModels, defaultModel: provider.defaultModel)
        if baseUrlField.stringValue.isEmpty { baseUrlField.placeholderString = provider.baseUrl }
    }

    private func updateModelPopup(models: [String], defaultModel: String) {
        modelPopup.removeAllItems()
        for m in models { modelPopup.addItem(withTitle: m) }
        if let idx = models.firstIndex(of: defaultModel) { modelPopup.selectItem(at: idx) }
    }

    @objc private func toggleKeyVisibility() {
        isKeyVisible.toggle()
        apiKeyToggleBtn.image = NSImage(systemSymbolName: isKeyVisible ? "eye" : "eye.slash", accessibilityDescription: "")
    }

    @objc private func testConnection() {
        llmStatusLabel.stringValue = "正在测试..."; llmStatusLabel.textColor = .systemBlue; testBtn.isEnabled = false
        let config = buildLLMConfig()
        let client = LLMClient(config: config)
        Task { @MainActor in
            do {
                if try await client.testConnection() {
                    llmStatusLabel.stringValue = "✅ 连接成功"; llmStatusLabel.textColor = .systemGreen
                } else {
                    llmStatusLabel.stringValue = "❌ 连接失败"; llmStatusLabel.textColor = .systemRed
                }
            } catch {
                llmStatusLabel.stringValue = "❌ \(error.localizedDescription)"; llmStatusLabel.textColor = .systemRed
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

    func loadSettings() {
        let prefs = ConfigStore()
        let config = prefs.loadLLMConfig()
        let provider = LLMProvider.byId(config.provider)
        if let idx = LLMProvider.all.firstIndex(where: { $0.id == config.provider }) { providerPopup.selectItem(at: idx) }
        updateModelPopup(models: provider.availableModels, defaultModel: config.model.isEmpty ? provider.defaultModel : config.model)
        if !config.apiKey.isEmpty { apiKeyField.stringValue = config.apiKey; isKeyVisible = true }
        if !config.baseUrl.isEmpty { baseUrlField.stringValue = config.baseUrl }
        showMenubarCheckbox?.state = prefs.shouldShowMenubar() ? .on : .off
        launchAtLoginCheckbox?.state = LaunchAtLogin.isEnabled ? .on : .off
        autoUpdateCheckbox?.state = prefs.shouldAutoUpdate() ? .on : .off
        toggleHotkeyField?.stringValue = prefs.getToggleMenubarHotkey()
        updatePermissionStatus()
    }

    private func updatePermissionStatus() {
        let hi = PermissionChecker.hasInputMonitoringPermission()
        let ha = PermissionChecker.hasAccessibilityPermission()
        inputMonStatus.stringValue = hi ? "✅ 输入监控 — 已授权" : "❌ 输入监控 — 未授权"
        inputMonStatus.textColor = hi ? .systemGreen : .systemRed
        accessStatus.stringValue = ha ? "✅ 辅助功能 — 已授权" : "❌ 辅助功能 — 未授权"
        accessStatus.textColor = ha ? .systemGreen : .systemRed
        permFixBtn.isHidden = hi && ha
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

enum LaunchAtLogin {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set { try? SMAppService.mainApp.unregister(); if newValue { try? SMAppService.mainApp.register() } }
    }
}
