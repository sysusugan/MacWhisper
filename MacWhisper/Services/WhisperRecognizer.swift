import Foundation
import AVFoundation
import WhisperKit

@MainActor
class WhisperRecognizer: ObservableObject {
    @Published var isModelLoaded = false
    @Published var pipelineState: PipelineState = .notStarted
    @Published var availableModels: [String] = []
    @Published var recommendedModel: String = ""
    @Published var selectedModel: String = WhisperRecognizer.defaultModel
    @Published var preferredLanguage: TranscriptionLanguage = .chinese

    private var whisperKit: WhisperKit?
    private var resultCallback: ((String) -> Void)?
    private var streamingTask: Task<Void, Never>?
    private var loadingTask: Task<Void, Never>?
    private var transcriptionGeneration = 0

    // MARK: - Chunked Transcription State
    // These track segment confirmation for efficient long recording support.
    // Only the last N segments stay "unconfirmed" and may be revised as more audio arrives.
    // Earlier segments are "confirmed" and their text is stable.
    private var lastConfirmedSegmentEndSeconds: Float = 0
    private var confirmedSegments: [TranscriptionSegment] = []
    private var unconfirmedSegments: [TranscriptionSegment] = []
    private var confirmedText: String = ""
    private var sessionDetectedLanguageCode: String?
    private let requiredSegmentsForConfirmation: Int = 2

    /// Expose WhisperKit's AudioProcessor for proper audio capture with AVAudioConverter resampling
    var audioProcessor: (any AudioProcessing)? {
        whisperKit?.audioProcessor
    }

    /// Shared fallback model list used when the WhisperKit API returns no recommendations.
    /// Also referenced by ModelsLibraryView.
    nonisolated static let defaultModel = "large-v3_turbo"
    nonisolated private static let legacyDefaultModel = "distil-whisper_distil-large-v3_turbo"
    nonisolated private static let legacyPrefixedLargeV3TurboModel = "openai_whisper-large-v3_turbo"

    static let defaultModelList: [String] = [
        "large-v3_turbo",
        "large-v3_turbo_955MB",
        "large-v3",
        "large-v3_947MB",
        "large-v3_turbo_954MB",
        "distil-large-v3",
        "distil-large-v3_594MB",
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
            case .notStarted: return "未下载"
            case .downloading(let p): return "下载中 \(Int(p * 100))%"
            case .downloaded: return "已下载"
            case .loading: return "正在加载模型..."
            case .specializing: return "正在为你的 Mac 优化..."
            case .ready: return "已就绪"
            case .error(let msg): return msg
            case .cancelled: return "已取消"
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
        selectedModel = Self.resolveSelectedModel(savedModel: defaults.string(forKey: "whisperModel"))
    }

    func saveSelectedModel() {
        UserDefaults.standard.set(selectedModel, forKey: "whisperModel")
    }

    nonisolated static func resolveSelectedModel(savedModel: String?) -> String {
        guard let savedModel, !savedModel.isEmpty else {
            return defaultModel
        }

        if savedModel == legacyDefaultModel || savedModel == legacyPrefixedLargeV3TurboModel {
            return defaultModel
        }

        return savedModel
    }

    func fetchAvailableModels() {
        let support = WhisperKit.recommendedModels()
        recommendedModel = support.default
        let models = support.supported
        if !models.isEmpty {
            availableModels = models
        } else {
            availableModels = Self.defaultModelList
        }

        let resolvedModel = Self.resolveSelectedModel(
            savedModel: selectedModel,
            availableModels: availableModels
        )
        if resolvedModel != selectedModel {
            selectedModel = resolvedModel
            saveSelectedModel()
        }
    }

    nonisolated static func resolveSelectedModel(savedModel: String?, availableModels: [String]) -> String {
        let resolved = resolveSelectedModel(savedModel: savedModel)
        guard !availableModels.isEmpty else {
            return resolved
        }

        if availableModels.contains(resolved) {
            return resolved
        }

        if availableModels.contains(defaultModel) {
            return defaultModel
        }

        return resolved
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

    // MARK: - Chunked Transcription Methods

    /// Reset chunked transcription state for a new recording session.
    /// Call this at the start of each recording.
    func resetChunkedState() {
        transcriptionGeneration += 1
        streamingTask?.cancel()
        streamingTask = nil
        lastConfirmedSegmentEndSeconds = 0
        confirmedSegments = []
        unconfirmedSegments = []
        confirmedText = ""
        sessionDetectedLanguageCode = nil
        print("WhisperRecognizer: Chunked state reset for new recording")
    }

    /// Finalize all remaining unconfirmed segments.
    /// Call this when recording stops to include all pending segments in the final result.
    func finalizeAllSegments() -> String {
        if !unconfirmedSegments.isEmpty {
            confirmedSegments.append(contentsOf: unconfirmedSegments)
            unconfirmedSegments = []
            print("WhisperRecognizer: Finalized \(confirmedSegments.count) total segments")
        }
        confirmedText = confirmedSegments.map { $0.text }.joined(separator: " ")
        return confirmedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Process transcription segments and manage confirmation state.
    /// Confirms all but the last N segments to allow revision of recent audio.
    private func processSegments(_ segments: [TranscriptionSegment]) {
        if segments.count > requiredSegmentsForConfirmation {
            // Confirm earlier segments, keep last N unconfirmed
            let numberOfSegmentsToConfirm = segments.count - requiredSegmentsForConfirmation
            let toConfirm = Array(segments.prefix(numberOfSegmentsToConfirm))
            let remaining = Array(segments.suffix(requiredSegmentsForConfirmation))

            // Only update if we're making forward progress
            if let lastConfirmed = toConfirm.last, lastConfirmed.end > lastConfirmedSegmentEndSeconds {
                lastConfirmedSegmentEndSeconds = lastConfirmed.end
                print("WhisperRecognizer: Confirmed up to \(String(format: "%.2f", lastConfirmedSegmentEndSeconds))s")

                // Add new confirmed segments (avoid duplicates by checking timestamps)
                for segment in toConfirm {
                    if !confirmedSegments.containsSegment(segment) {
                        confirmedSegments.append(segment)
                    }
                }
                confirmedText = confirmedSegments.map { $0.text }.joined(separator: " ")
                print("WhisperRecognizer: \(confirmedSegments.count) confirmed, \(remaining.count) unconfirmed")
            }
            unconfirmedSegments = remaining
        } else {
            // Not enough segments to confirm any - all stay unconfirmed
            unconfirmedSegments = segments
        }
    }

    /// Build the current display text from confirmed + unconfirmed segments.
    private func getCurrentDisplayText() -> String {
        let unconfirmedText = unconfirmedSegments.map { $0.text }.joined(separator: " ")
        let combined = (confirmedText + " " + unconfirmedText).trimmingCharacters(in: .whitespacesAndNewlines)
        return combined
    }

    /// Called from AppState after audio engine delivers a buffer.
    /// The actual buffer processing happens in AppState to avoid actor isolation issues.
    func handlePartialSamples(_ samples: [Float]) {
        guard let whisperKit = whisperKit else { return }

        let generation = transcriptionGeneration
        let clipStart = lastConfirmedSegmentEndSeconds
        let preferredLanguage = preferredLanguage
        let lockedLanguageCode = sessionDetectedLanguageCode

        streamingTask?.cancel()
        streamingTask = Task.detached(priority: .userInitiated) { [weak self, whisperKit] in
            await self?.transcribePartial(
                samples,
                using: whisperKit,
                language: preferredLanguage,
                lockedLanguageCode: lockedLanguageCode,
                clipStart: clipStart,
                generation: generation
            )
        }
    }

    nonisolated private func transcribePartial(
        _ samples: [Float],
        using whisperKit: WhisperKit,
        language: TranscriptionLanguage,
        lockedLanguageCode: String?,
        clipStart: Float,
        generation: Int
    ) async {
        guard !Task.isCancelled else { return }
        do {
            // Use clipTimestamps to skip already-confirmed audio for efficiency.
            // This prevents re-transcribing the entire buffer on long recordings.
            let options = Self.makeDecodingOptions(
                language: language,
                lockedLanguageCode: lockedLanguageCode,
                clipStart: clipStart
            )

            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)

            guard !Task.isCancelled, let result = results.first else { return }
            await MainActor.run { [weak self] in
                self?.applyPartialResult(result, generation: generation)
            }
        } catch {
            if !Task.isCancelled {
                print("WhisperRecognizer: Partial transcription error - \(error)")
                // Don't reset chunked state on transient errors - preserve confirmed text
            }
        }
    }

    nonisolated static func makeDecodingOptions(
        language: TranscriptionLanguage,
        lockedLanguageCode: String?,
        clipStart: Float
    ) -> DecodingOptions {
        let resolvedLanguageCode: String?
        let shouldDetectLanguage: Bool
        let usePrefillPrompt: Bool

        switch language {
        case .auto:
            if let lockedLanguageCode, !lockedLanguageCode.isEmpty {
                resolvedLanguageCode = lockedLanguageCode
                shouldDetectLanguage = false
                usePrefillPrompt = true
            } else {
                resolvedLanguageCode = nil
                shouldDetectLanguage = true
                usePrefillPrompt = false
            }
        case .chinese, .english:
            resolvedLanguageCode = language.whisperLanguageCode
            shouldDetectLanguage = false
            usePrefillPrompt = true
        }

        return DecodingOptions(
            language: resolvedLanguageCode,
            temperatureFallbackCount: 0,
            sampleLength: 224,
            usePrefillPrompt: usePrefillPrompt,
            detectLanguage: shouldDetectLanguage,
            skipSpecialTokens: true,
            wordTimestamps: true,
            clipTimestamps: [clipStart]
        )
    }

    private func applyPartialResult(_ result: TranscriptionResult, generation: Int) {
        guard generation == transcriptionGeneration else { return }

        if preferredLanguage == .auto,
           sessionDetectedLanguageCode == nil,
           !result.language.isEmpty {
            sessionDetectedLanguageCode = result.language
        }

        let segments = result.segments

        // Handle case where no segments returned (very short audio or silence)
        if segments.isEmpty {
            // Fall back to raw text for very short recordings
            if !result.text.isEmpty {
                let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                // Still deliver via callback even without segments
                let displayText = (confirmedText + " " + text).trimmingCharacters(in: .whitespacesAndNewlines)
                resultCallback?(displayText)
            }
            return
        }

        // Process segments through confirmation logic
        processSegments(segments)

        // Deliver combined confirmed + unconfirmed text
        let displayText = getCurrentDisplayText()
        if !displayText.isEmpty {
            resultCallback?(displayText)
        }
    }

    /// Stop recording. Waits for any in-flight partial to finish (which transcribes
    /// the full buffer), then finalizes all segments and returns the complete transcription.
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

        // Finalize all remaining unconfirmed segments and return the complete text
        let finalText = finalizeAllSegments()
        print("WhisperRecognizer: Recording finished with \(confirmedSegments.count) total segments")
        return finalText
    }
}

// MARK: - Array Extension for Segment Containment

extension Array where Element == TranscriptionSegment {
    /// Check if array contains a segment with matching timestamps (within tolerance).
    /// Uses timestamp comparison rather than exact equality since segment text may have been cleaned.
    func containsSegment(_ segment: TranscriptionSegment, tolerance: Float = 0.1) -> Bool {
        return self.contains { existing in
            abs(existing.start - segment.start) < tolerance &&
            abs(existing.end - segment.end) < tolerance
        }
    }
}
