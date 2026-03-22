import SwiftUI
import CoreAudio

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // Recording toggle
        Button {
            appState.isRecording.toggle()
        } label: {
            Label(
                appState.isRecording ? "Stop Recording" : "Start Recording",
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
            Button("Cancel Loading") {
                appState.whisperRecognizer.cancelLoading()
            }
        }

        if case .error = appState.whisperRecognizer.pipelineState {
            Text(appState.whisperRecognizer.pipelineState.statusText)
                .font(.caption)
                .foregroundColor(.red)
            Button("Retry Model Load") {
                appState.retryModelLoad()
            }
        }

        if case .cancelled = appState.whisperRecognizer.pipelineState {
            Text("Model not loaded")
                .font(.caption)
            Button("Load Model") {
                appState.whisperRecognizer.loadModel()
            }
        }

        // Processing status
        if appState.isProcessing {
            Text("Transcribing...")
                .font(.caption)
        }

        Button {
            // Placeholder
        } label: {
            Label("Transcribe File...", systemImage: "lock.fill")
        }
        .disabled(true)

        Button {
            // Placeholder
        } label: {
            Label("History...", systemImage: "clock")
        }
        .disabled(true)

        Button {
            SettingsWindowController.shared.open(appState: appState)
        } label: {
            Label("Settings...", systemImage: "gear")
        }
        .keyboardShortcut(",")

        Divider()

        // Audio input device
        Menu(currentInputDeviceName) {
            Text("Default input device")
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

        Text("Version 1.0")

        Button("Check for Updates...") {
            // Placeholder
        }
        .disabled(true)

        Button("Quit") {
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
            return "Microphone"
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
            return "Microphone"
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
                styleName = "Custom"
            }
        }
        return "Style: \(styleName)"
    }
}
