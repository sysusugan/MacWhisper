import Foundation
import AVFoundation
import WhisperKit

@MainActor
class WhisperRecognizer: ObservableObject {
    @Published var isModelLoaded = false
    @Published var pipelineState: PipelineState = .notStarted
    @Published var availableModels: [String] = []
    @Published var selectedModel: String = "distil-whisper_distil-large-v3_turbo"

    private var whisperKit: WhisperKit?
    private var resultCallback: ((String) -> Void)?
    private var streamingTask: Task<Void, Never>?
    private var loadingTask: Task<Void, Never>?

    /// Expose WhisperKit's AudioProcessor for proper audio capture with AVAudioConverter resampling
    var audioProcessor: (any AudioProcessing)? {
        whisperKit?.audioProcessor
    }

    /// Shared fallback model list used when the WhisperKit API returns no recommendations.
    /// Also referenced by ModelsLibraryView.
    static let defaultModelList: [String] = [
        "openai_whisper-large-v3-v20240930_turbo",
        "openai_whisper-large-v3_turbo",
        "openai_whisper-large-v3",
        "distil-whisper_distil-large-v3_turbo",
        "openai_whisper-small.en",
        "openai_whisper-base.en",
        "openai_whisper-tiny.en",
    ]

    enum PipelineState: Equatable {
        case notStarted
        case downloading(progress: Double)
        case downloaded
        case loading
        case specializing
        case ready
        case error(String)
        case cancelled

        var statusText: String {
            switch self {
            case .notStarted: return "Not downloaded"
            case .downloading(let p): return "Downloading \(Int(p * 100))%"
            case .downloaded: return "Downloaded"
            case .loading: return "Loading model..."
            case .specializing: return "Optimizing for your Mac..."
            case .ready: return "Ready"
            case .error(let msg): return msg
            case .cancelled: return "Cancelled"
            }
        }

        var isBusy: Bool {
            switch self {
            case .downloading, .loading, .specializing, .downloaded: return true
            default: return false
            }
        }
    }

    init() {
        loadSelectedModel()
    }

    private func loadSelectedModel() {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: "whisperModel") {
            selectedModel = saved
        }
    }

    func saveSelectedModel() {
        UserDefaults.standard.set(selectedModel, forKey: "whisperModel")
    }

    func fetchAvailableModels() {
        let models = WhisperKit.recommendedModels().supported
        if !models.isEmpty {
            availableModels = models
        } else {
            availableModels = Self.defaultModelList
        }
    }

    /// Cancel the current model loading task
    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        whisperKit = nil
        isModelLoaded = false
        pipelineState = .cancelled
        print("WhisperRecognizer: Model loading cancelled by user")
    }

    /// Load model on a background thread so it never blocks main actor or cooperative pool.
    func loadModel() {
        loadingTask?.cancel()
        loadingTask = nil

        let modelName = selectedModel
        pipelineState = .loading
        isModelLoaded = false
        whisperKit = nil

        // Use Task.detached to avoid inheriting the @MainActor context.
        // WhisperKit init is heavy and blocks the thread — if run on the cooperative
        // pool it starves all other tasks (including cancel/timeout).
        loadingTask = Task.detached { [weak self] in
            print("WhisperRecognizer: Loading '\(modelName)' on background thread...")

            do {
                try Task.checkCancellation()
                let kit = try await WhisperKit(
                    model: modelName,
                    verbose: true,
                    logLevel: .info,
                    prewarm: false
                )
                try Task.checkCancellation()

                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.whisperKit = kit
                    self.isModelLoaded = true
                    self.pipelineState = .ready
                    self.saveSelectedModel()
                    self.loadingTask = nil
                }
                print("WhisperRecognizer: Model '\(modelName)' loaded successfully")
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    if self.pipelineState != .cancelled {
                        self.pipelineState = .cancelled
                    }
                    self.isModelLoaded = false
                    self.loadingTask = nil
                }
                print("WhisperRecognizer: Cancelled")
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.pipelineState = .error(error.localizedDescription)
                    self.isModelLoaded = false
                    self.loadingTask = nil
                }
                print("WhisperRecognizer: Failed - \(error)")
            }
        }
    }

    func startRecognition(onResult: @escaping (String) -> Void) {
        resultCallback = onResult
    }

    /// Called from AppState after audio engine delivers a buffer.
    /// The actual buffer processing happens in AppState to avoid actor isolation issues.
    func handlePartialSamples(_ samples: [Float]) {
        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self = self else { return }
            await self.transcribePartial(samples)
        }
    }

    private func transcribePartial(_ samples: [Float]) async {
        guard let whisperKit = whisperKit, !Task.isCancelled else { return }

        do {
            let options = DecodingOptions(
                language: "en",
                temperatureFallbackCount: 0,
                sampleLength: 224,
                usePrefillPrompt: true,
                skipSpecialTokens: true
            )
            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
            if !Task.isCancelled, let text = results.first?.text, !text.isEmpty {
                resultCallback?(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch {
            if !Task.isCancelled {
                print("WhisperRecognizer: Partial transcription error - \(error)")
            }
        }
    }

    /// Stop recording. Waits for any in-flight partial to finish (which transcribes
    /// the full buffer), then returns its result. No second transcription call.
    func finishRecognition() async -> String {

        // Don't nil the callback yet — let the streaming task deliver its final result
        // If a streaming task is running, wait for it to complete (don't cancel —
        // let it finish so we get the most complete transcription)
        if let task = streamingTask {
            _ = await task.value
            streamingTask = nil
        }

        // Now nil the callback since we're done delivering results
        resultCallback = nil

        // The last successful partial result was already delivered via resultCallback
        // which updated currentTranscription in AppState. Return empty to signal
        // "use currentTranscription".
        return ""
    }
}

