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

    // MARK: - Chunked Transcription State
    // These track segment confirmation for efficient long recording support.
    // Only the last N segments stay "unconfirmed" and may be revised as more audio arrives.
    // Earlier segments are "confirmed" and their text is stable.
    private var lastConfirmedSegmentEndSeconds: Float = 0
    private var confirmedSegments: [TranscriptionSegment] = []
    private var unconfirmedSegments: [TranscriptionSegment] = []
    private var confirmedText: String = ""
    private let requiredSegmentsForConfirmation: Int = 2

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

    // MARK: - Chunked Transcription Methods

    /// Reset chunked transcription state for a new recording session.
    /// Call this at the start of each recording.
    func resetChunkedState() {
        lastConfirmedSegmentEndSeconds = 0
        confirmedSegments = []
        unconfirmedSegments = []
        confirmedText = ""
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
        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self = self else { return }
            await self.transcribePartial(samples)
        }
    }

    private func transcribePartial(_ samples: [Float]) async {
        guard let whisperKit = whisperKit, !Task.isCancelled else { return }

        do {
            // Use clipTimestamps to skip already-confirmed audio for efficiency.
            // This prevents re-transcribing the entire buffer on long recordings.
            let options = DecodingOptions(
                language: "en",
                temperatureFallbackCount: 0,
                sampleLength: 224,
                usePrefillPrompt: true,
                skipSpecialTokens: true,
                wordTimestamps: true,
                clipTimestamps: [lastConfirmedSegmentEndSeconds]
            )

            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)

            guard !Task.isCancelled, let result = results.first else { return }

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
        } catch {
            if !Task.isCancelled {
                print("WhisperRecognizer: Partial transcription error - \(error)")
                // Don't reset chunked state on transient errors - preserve confirmed text
            }
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

