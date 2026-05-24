import SwiftUI
import CoreAudio

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var updaterManager = UpdaterManager.shared

    var body: some View {
        // Recording toggle
        Button {
            appState.isRecording.toggle()
        } label: {
            Label(
                appState.isRecording ? "停止录音" : "开始录音",
                systemImage: appState.isRecording ? "stop.fill" : "record.circle"
            )
        }
        .disabled(!appState.whisperRecognizer.isModelLoaded && !appState.isRecording)

        // Model loading status
        if appState.whisperRecognizer.pipelineState.isBusy {
            HStack {
                Text(appState.whisperRecognizer.pipelineState.statusText)
                    .font(.caption)
            }
            Button("取消加载") {
                appState.whisperRecognizer.cancelLoading()
            }
        }

        if case .error = appState.whisperRecognizer.pipelineState {
            Text(appState.whisperRecognizer.pipelineState.statusText)
                .font(.caption)
                .foregroundColor(.red)
            Button("重新加载模型") {
                appState.retryModelLoad()
            }
        }

        if case .cancelled = appState.whisperRecognizer.pipelineState {
            Text("模型未加载")
                .font(.caption)
            Button("加载模型") {
                appState.whisperRecognizer.loadModel()
            }
        }

        // Processing status
        if appState.isProcessing {
            Text("转写中...")
                .font(.caption)
        }

        Button {
            // Placeholder
        } label: {
            Label("转写文件...", systemImage: "lock.fill")
        }
        .disabled(true)

        Button {
            // Placeholder
        } label: {
            Label("历史记录...", systemImage: "clock")
        }
        .disabled(true)

        Button {
            SettingsWindowController.shared.open(appState: appState)
        } label: {
            Label("设置...", systemImage: "gear")
        }
        .keyboardShortcut(",")

        Divider()

        // Audio input device
        Menu(currentInputDeviceName) {
            Text("默认输入设备")
        }

        // Style submenu
        Menu(styleMenuTitle) {
            ForEach(TranscriptionMode.BuiltIn.allCases) { mode in
                Button {
                    appState.selectedMode = .builtIn(mode)
                    appState.saveSettings()
                } label: {
                    HStack {
                        Text(mode.displayName)
                        if appState.selectedMode == .builtIn(mode) {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if !appState.customModes.isEmpty {
                Divider()
                ForEach(appState.customModes) { mode in
                    Button {
                        appState.selectedMode = .custom(mode.id)
                        appState.saveSettings()
                    } label: {
                        HStack {
                            Text(mode.name)
                            if appState.selectedMode == .custom(mode.id) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }

        Divider()

        Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")

        Button("检查更新...") {
            updaterManager.checkForUpdates()
        }
        .disabled(!updaterManager.canCheckForUpdates)

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var currentInputDeviceName: String {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == noErr else {
            return "麦克风"
        }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &size, &name) == noErr,
              let cfName = name?.takeUnretainedValue() else {
            return "麦克风"
        }

        return cfName as String
    }

    private var styleMenuTitle: String {
        let styleName: String
        switch appState.selectedMode {
        case .builtIn(let b):
            styleName = b.displayName
        case .custom(let id):
            if let mode = appState.customModes.first(where: { $0.id == id }) {
                styleName = mode.name
            } else {
                styleName = "自定义"
            }
        }
        return "样式：\(styleName)"
    }
}
