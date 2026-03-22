import SwiftUI
import Combine
import AVFoundation
import WhisperKit

enum OverlayMode: Equatable {
    case recording
    case processing
    case modelLoading
}

@MainActor
class AudioLevelMonitor: ObservableObject {
    @Published var level: Float = 0
    @Published var mode: OverlayMode = .recording

    // Adaptive normalization: tracks recent peak to scale output to full range
    private var recentPeak: Float = 0.001
    private let peakDecay: Float = 0.998  // slow decay so peak stays stable
    private let minPeak: Float = 0.001    // floor to avoid division by near-zero

    func update(_ rawLevel: Float) {
        // Track the running peak (fast attack, slow decay)
        if rawLevel > recentPeak {
            recentPeak = rawLevel
        } else {
            recentPeak = max(minPeak, recentPeak * peakDecay)
        }

        // Normalize against recent peak so quiet/loud voices both fill 0-1
        let normalized = min(1.0, rawLevel / recentPeak)
        level = level * 0.25 + normalized * 0.75
    }

    func reset() {
        level = 0
        recentPeak = 0.001
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var currentTranscription = ""
    @Published var selectedMode: TranscriptionMode = .default
    @Published var customModes: [CustomMode] = []
    @Published var hotkeyConfig: HotkeyConfig = .defaultConfig
    @Published var isProcessing = false
    @Published var lastTranscription = ""
    @Published var showOverlay = false
    @Published var autoPaste = true
    @Published var formatText = true
    @Published var permissionsGranted = false

    // Services
    lazy var whisperRecognizer = WhisperRecognizer()
    lazy var hotkeyManager = HotkeyManager()
    lazy var clipboardManager = ClipboardManager()
    lazy var textFormatter = TextFormatter()
    let audioLevelMonitor = AudioLevelMonitor()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Register defaults so bool(forKey:) and double(forKey:) return correct values
        UserDefaults.standard.register(defaults: [
            StorageKeys.playStartSound: true,
            StorageKeys.playStopSound: true,
            StorageKeys.soundVolume: 1.0,
            StorageKeys.autoPaste: true,
            StorageKeys.formatText: true,
        ])

        loadSettings()
        setupBindings()

        // Forward nested ObservableObject changes so views observing AppState
        // (e.g. MenuBarView via @EnvironmentObject) re-render when
        // whisperRecognizer or hotkeyManager publish changes.
        whisperRecognizer.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        hotkeyManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        requestPermissionsOnce {
            print("AppState: Permissions callback fired, scheduling hotkey monitoring in 0.5s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else {
                    print("AppState: self was deallocated before hotkey monitoring could start")
                    return
                }
                self.startHotkeyMonitoring()
            }
        }
        // Load whisper model in background (non-blocking, cancellable)
        whisperRecognizer.loadModel()
    }

    private func requestPermissionsOnce(completion: @escaping () -> Void) {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .authorized {
            permissionsGranted = true
            completion()
            return
        }

        AVCaptureDevice.requestAccess(for: .audio) { [weak self] micGranted in
            DispatchQueue.main.async {
                self?.permissionsGranted = micGranted
                completion()
            }
        }
    }

    /// Retry loading the whisper model (callable from menu/settings)
    func retryModelLoad() {
        whisperRecognizer.cancelLoading()
        whisperRecognizer.loadModel()
    }

    func startHotkeyMonitoring() {
        print("AppState: startHotkeyMonitoring() called — setting up hotkey with config: hold='\(hotkeyConfig.holdKey.displayString)' toggle='\(hotkeyConfig.toggleCombo.displayString)'")
        hotkeyManager.start(config: hotkeyConfig) { [weak self] shouldRecord in
            DispatchQueue.main.async {
                print("AppState: Recording state changed to \(shouldRecord)")
                self?.isRecording = shouldRecord
            }
        }
    }

    func setupBindings() {
        $isRecording
            .removeDuplicates()
            .sink { [weak self] recording in
                if recording {
                    self?.startRecording()
                } else {
                    self?.stopRecording()
                }
            }
            .store(in: &cancellables)
    }

    func startRecording() {
        guard whisperRecognizer.isModelLoaded else {
            print("AppState: Whisper model not loaded yet")
            isRecording = false
            hotkeyManager.state = .idle

            // Show brief "loading model" overlay
            audioLevelMonitor.mode = .modelLoading
            RecordingOverlayController.shared.show(appState: self)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if audioLevelMonitor.mode == .modelLoading {
                    audioLevelMonitor.mode = .recording
                    RecordingOverlayController.shared.hide()
                }
            }
            return
        }

        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .notDetermined {
            print("AppState: Microphone permission not yet requested, requesting now")
            isRecording = false
            hotkeyManager.state = .idle
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionsGranted = granted
                    if granted {
                        self?.isRecording = true
                    }
                }
            }
            return
        }
        if micStatus != .authorized {
            print("AppState: Microphone permission denied — opening settings")
            isRecording = false
            hotkeyManager.state = .idle
            permissionsGranted = false
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        permissionsGranted = true

        currentTranscription = ""
        showOverlay = true
        audioLevelMonitor.mode = .recording
        RecordingOverlayController.shared.hide()  // dismiss any stale model-loading overlay
        RecordingOverlayController.shared.show(appState: self)

        let defaults = UserDefaults.standard
        if defaults.bool(forKey: StorageKeys.playStartSound) {
            let volume = Float(defaults.double(forKey: StorageKeys.soundVolume))
            if let sound = NSSound(named: .init("Tink")) {
                sound.volume = volume
                sound.play()
            }
        }
        print("AppState: Recording started")

        whisperRecognizer.startRecognition { [weak self] result in
            DispatchQueue.main.async {
                self?.currentTranscription = result
            }
        }

        guard let audioProcessor = whisperRecognizer.audioProcessor else {
            print("AppState: AudioProcessor not available")
            isRecording = false
            hotkeyManager.state = .idle
            return
        }

        var lastTranscribedCount = 0
        var lastLevelSampleCount = 0
        do {
            try audioProcessor.startRecordingLive(inputDeviceID: nil) { [weak self] _ in
                guard let self = self else { return }
                let currentCount = audioProcessor.audioSamples.count

                // Update audio level for overlay visualization (~20fps)
                if currentCount - lastLevelSampleCount >= 800 {
                    lastLevelSampleCount = currentCount
                    let levelSamples = audioProcessor.audioSamples
                    let chunkSize = min(1600, levelSamples.count)
                    if chunkSize > 0 {
                        var sumSquares: Float = 0
                        let start = levelSamples.count - chunkSize
                        for i in start..<levelSamples.count {
                            let s = levelSamples[i]
                            sumSquares += s * s
                        }
                        let rms = sqrt(sumSquares / Float(chunkSize))
                        Task { @MainActor [weak self] in
                            self?.audioLevelMonitor.update(rms)
                        }
                    }
                }

                guard currentCount >= 32000, currentCount - lastTranscribedCount >= 32000 else { return }
                lastTranscribedCount = currentCount
                let samples = Array(audioProcessor.audioSamples)
                Task { @MainActor [weak self] in
                    self?.whisperRecognizer.handlePartialSamples(samples)
                }
            }
        } catch {
            print("AppState: Failed to start recording — \(error)")
            isRecording = false
            hotkeyManager.state = .idle
        }
    }

    func stopRecording() {
        // Guard against being called when no recording is active
        guard showOverlay else { return }

        whisperRecognizer.audioProcessor?.stopRecording()
        showOverlay = false
        audioLevelMonitor.reset()
        audioLevelMonitor.mode = .processing
        // Keep overlay visible — switch to processing animation
        isProcessing = true

        let defaults = UserDefaults.standard
        if defaults.bool(forKey: StorageKeys.playStopSound) {
            let volume = Float(defaults.double(forKey: StorageKeys.soundVolume))
            if let sound = NSSound(named: .init("Pop")) {
                sound.volume = volume
                sound.play()
            }
        }
        print("AppState: Recording stopped, waiting for transcription...")

        Task { @MainActor in
            // Send complete audio buffer for final transcription (fixes sentence cutoff)
            if let processor = whisperRecognizer.audioProcessor {
                let finalSamples = Array(processor.audioSamples)
                if !finalSamples.isEmpty {
                    whisperRecognizer.handlePartialSamples(finalSamples)
                }
            }

            // Wait for the final transcription to complete
            _ = await whisperRecognizer.finishRecognition()

            let text = currentTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
            isProcessing = false
            audioLevelMonitor.mode = .recording
            RecordingOverlayController.shared.hide()

            guard !text.isEmpty else {
                print("AppState: Transcription was empty, skipping save")
                return
            }

            let formatted = formatText
                ? textFormatter.format(text, mode: selectedMode, customModes: customModes)
                : text

            lastTranscription = formatted

            // Save to transcription history
            let modeName: String
            switch selectedMode {
            case .builtIn(let b): modeName = b.displayName
            case .custom(let id): modeName = customModes.first(where: { $0.id == id })?.name ?? "Custom"
            }
            HistorySettingsView.addRecord(text: formatted, mode: modeName)

            clipboardManager.copyToClipboard(formatted)

            if autoPaste {
                try? await Task.sleep(nanoseconds: 150_000_000)
                clipboardManager.pasteFromClipboard()
            }
        }
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        autoPaste = defaults.object(forKey: StorageKeys.autoPaste) as? Bool ?? true
        formatText = defaults.object(forKey: StorageKeys.formatText) as? Bool ?? true

        if let data = defaults.data(forKey: StorageKeys.hotkeyConfig),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            hotkeyConfig = config
        }

        if let data = defaults.data(forKey: StorageKeys.customModes),
           let modes = try? JSONDecoder().decode([CustomMode].self, from: data) {
            customModes = modes
        }

        if let modeRaw = defaults.string(forKey: StorageKeys.selectedMode) {
            if let builtin = TranscriptionMode.BuiltIn(rawValue: modeRaw) {
                selectedMode = .builtIn(builtin)
            } else if modeRaw.hasPrefix("custom_"),
                      let uuid = UUID(uuidString: String(modeRaw.dropFirst(7))) {
                selectedMode = .custom(uuid)
            }
        }

        // Validate that a custom mode still exists; fall back if deleted
        if case .custom(let id) = selectedMode {
            if !customModes.contains(where: { $0.id == id }) {
                selectedMode = .builtIn(.professional)
            }
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(autoPaste, forKey: StorageKeys.autoPaste)
        defaults.set(formatText, forKey: StorageKeys.formatText)

        if let data = try? JSONEncoder().encode(hotkeyConfig) {
            defaults.set(data, forKey: StorageKeys.hotkeyConfig)
        }

        if let data = try? JSONEncoder().encode(customModes) {
            defaults.set(data, forKey: StorageKeys.customModes)
        }

        switch selectedMode {
        case .builtIn(let builtin):
            defaults.set(builtin.rawValue, forKey: StorageKeys.selectedMode)
        case .custom(let id):
            defaults.set("custom_\(id.uuidString)", forKey: StorageKeys.selectedMode)
        }
    }
}
