import AVFoundation
import Foundation

// NOTE: This class is no longer used — audio capture now goes through
// WhisperKit's built-in AudioProcessor (via WhisperRecognizer.audioProcessor).
// Safe to delete this file.

@MainActor
class AudioEngine {
    private var audioEngine = AVAudioEngine()
    private var isRunning = false

    func startCapture(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) {
        guard !isRunning else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else { return }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
            onBuffer(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRunning = true
        } catch {
            print("AudioEngine: Failed to start - \(error.localizedDescription)")
        }
    }

    func stopCapture() {
        guard isRunning else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRunning = false
    }

    func cleanup() {
        stopCapture()
    }
}
