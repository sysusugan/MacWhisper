import SwiftUI
import ServiceManagement

struct ConfigurationSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("showInDock") private var showInDock = false

    var body: some View {
        Form {
            Section("快捷键") {
                VStack(spacing: 4) {
                    Text("录音快捷键")
                        .font(.headline)
                    Text("两个快捷键会一直生效。按住适合快速口述，切换适合免手操作。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

                ConfigShortcutCard(
                    title: "按住",
                    subtitle: "按住开始录音，松开停止",
                    icon: "hand.tap",
                    combo: $appState.hotkeyConfig.holdKey
                )

                ConfigShortcutCard(
                    title: "切换",
                    subtitle: "按一次开始，再按一次停止",
                    icon: "arrow.triangle.2.circlepath",
                    combo: $appState.hotkeyConfig.toggleCombo
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("组合使用方式")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ConfigFlowRow(icon: "1.circle.fill", text: "按住 \(appState.hotkeyConfig.holdKey.displayString) 开始快速口述")
                    ConfigFlowRow(icon: "2.circle.fill", text: "按住期间，再按 \(comboKeyName) 可锁定持续录音")
                    ConfigFlowRow(icon: "3.circle.fill", text: "再次按 \(appState.hotkeyConfig.toggleCombo.displayString) 或轻点 \(appState.hotkeyConfig.holdKey.displayString) 即可停止")
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.04)))
            }

            Section("行为") {
                Toggle("录音结束后自动粘贴", isOn: $appState.autoPaste)
                    .onChange(of: appState.autoPaste) {
                        appState.saveSettings()
                    }
                Toggle("应用文本格式化", isOn: $appState.formatText)
                    .onChange(of: appState.formatText) {
                        appState.saveSettings()
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Picker("转写语言", selection: $appState.transcriptionLanguage) {
                        ForEach(TranscriptionLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .onChange(of: appState.transcriptionLanguage) {
                        appState.whisperRecognizer.preferredLanguage = appState.transcriptionLanguage
                        appState.saveSettings()
                    }

                    Text("说中文时建议配合非 .en 的多语言模型使用。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("系统") {
                Toggle("登录时启动", isOn: launchAtLoginBinding)

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("在 Dock 中显示", isOn: $showInDock)
                    Text("重启应用后生效。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("权限") {
                ConfigPermissionRow(icon: "mic.fill", label: "麦克风", granted: appState.permissionsGranted)
                if !appState.permissionsGranted {
                    Button("打开麦克风设置") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
                ConfigPermissionRow(icon: "hand.raised.fill", label: "辅助功能", granted: appState.hotkeyManager.accessibilityGranted)
                if !appState.hotkeyManager.accessibilityGranted {
                    Button("打开辅助功能设置") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
                ConfigPermissionRow(icon: "keyboard", label: "输入监控", granted: appState.hotkeyManager.inputMonitoringGranted)
                if !appState.hotkeyManager.inputMonitoringGranted {
                    Button("打开输入监控设置") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: appState.hotkeyConfig) {
            appState.hotkeyManager.updateConfig(appState.hotkeyConfig)
            appState.saveSettings()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: {
                SMAppService.mainApp.status == .enabled
            },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to update launch at login: \(error)")
                }
            }
        )
    }

    private var comboKeyName: String {
        if let kc = appState.hotkeyConfig.toggleCombo.keyCode {
            return keyCodeToString(kc)
        }
        return appState.hotkeyConfig.toggleCombo.displayString
    }
}

// MARK: - Supporting Views

struct ConfigShortcutCard: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var combo: KeyCombo

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            ConfigShortcutRecorderView(combo: $combo)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.12), lineWidth: 1))
    }
}

struct ConfigShortcutRecorderView: View {
    @Binding var combo: KeyCombo
    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var pendingModifiers = KeyModifiers()
    @State private var hadModifiers = false

    var body: some View {
        Button(action: {
            if isRecording {
                stopListening()
            } else {
                startListening()
            }
        }) {
            HStack(spacing: 6) {
                if isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)

                    if pendingModifiers.isEmpty {
                        Text("请按下按键...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text(pendingDisplay)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("松开即可设置")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(combo.displayString)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isRecording ? Color.red.opacity(0.08) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isRecording ? Color.red.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopListening()
        }
    }

    private var pendingDisplay: String {
        var p: [String] = []
        if pendingModifiers.control { p.append("⌃") }
        if pendingModifiers.option { p.append("⌥") }
        if pendingModifiers.shift { p.append("⇧") }
        if pendingModifiers.command { p.append("⌘") }
        if pendingModifiers.fn { p.append("fn") }
        return p.joined(separator: " ")
    }

    private func startListening() {
        isRecording = true
        pendingModifiers = KeyModifiers()
        hadModifiers = false

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
            if event.type == .flagsChanged {
                let current = KeyModifiers(
                    control: event.modifierFlags.contains(.control),
                    option: event.modifierFlags.contains(.option),
                    shift: event.modifierFlags.contains(.shift),
                    command: event.modifierFlags.contains(.command),
                    fn: event.modifierFlags.contains(.function)
                )

                if !current.isEmpty {
                    self.pendingModifiers = current
                    self.hadModifiers = true
                } else if self.hadModifiers {
                    self.combo = KeyCombo(keyCode: nil, modifiers: self.pendingModifiers)
                    self.stopListening()
                }
                return event
            }

            if event.type == .keyDown {
                let kc = event.keyCode
                let modKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
                if modKeys.contains(kc) { return event }

                if kc == 53 && self.pendingModifiers.isEmpty {
                    self.stopListening()
                    return nil
                }

                let mods = KeyModifiers(
                    control: event.modifierFlags.contains(.control),
                    option: event.modifierFlags.contains(.option),
                    shift: event.modifierFlags.contains(.shift),
                    command: event.modifierFlags.contains(.command),
                    fn: event.modifierFlags.contains(.function)
                )
                self.combo = KeyCombo(keyCode: kc, modifiers: mods)
                self.stopListening()
                return nil
            }
            return event
        }
    }

    private func stopListening() {
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
        isRecording = false
        pendingModifiers = KeyModifiers()
        hadModifiers = false
    }
}

struct ConfigFlowRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

struct ConfigPermissionRow: View {
    let icon: String
    let label: String
    let granted: Bool
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(label)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(granted ? .green : .red)
                Text(granted ? "已授权" : "需要授权")
                    .font(.caption)
                    .foregroundColor(granted ? .green : .red)
            }
        }
    }
}
