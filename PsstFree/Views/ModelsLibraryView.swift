import SwiftUI

struct ModelsLibraryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Models Library")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Select a Whisper model to use for transcription. Larger models are more accurate but use more memory.")
                .font(.caption)
                .foregroundColor(.secondary)

            ModelsLibraryStatusBanner(recognizer: appState.whisperRecognizer)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(modelList, id: \.self) { model in
                        ModelRow(
                            model: model,
                            displayName: modelDisplayName(model),
                            sizeEstimate: modelSizeEstimate(model),
                            isSelected: model == appState.whisperRecognizer.selectedModel,
                            recognizer: appState.whisperRecognizer
                        )
                    }
                }
            }
        }
        .padding()
        .onAppear {
            appState.whisperRecognizer.fetchAvailableModels()
        }
    }

    private var modelList: [String] {
        if !appState.whisperRecognizer.availableModels.isEmpty {
            return appState.whisperRecognizer.availableModels
        }
        return WhisperRecognizer.defaultModelList
    }

    private func modelDisplayName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "openai_whisper-", with: "")
            .replacingOccurrences(of: "distil-whisper_distil-", with: "distil-")
    }

    private func modelSizeEstimate(_ model: String) -> String {
        let lower = model.lowercased()
        if lower.contains("tiny") { return "~75 MB" }
        if lower.contains("base") { return "~140 MB" }
        if lower.contains("small") { return "~460 MB" }
        if lower.contains("medium") { return "~1.5 GB" }
        if lower.contains("large") && lower.contains("turbo") { return "~800 MB" }
        if lower.contains("large") { return "~3 GB" }
        if lower.contains("distil") { return "~800 MB" }
        return ""
    }
}

// MARK: - Model Row

private struct ModelRow: View {
    let model: String
    let displayName: String
    let sizeEstimate: String
    let isSelected: Bool
    @ObservedObject var recognizer: WhisperRecognizer

    private var isActive: Bool {
        isSelected && recognizer.pipelineState == .ready
    }

    private var isBusy: Bool {
        isSelected && recognizer.pipelineState.isBusy
    }

    private var isError: Bool {
        if case .error = recognizer.pipelineState, isSelected {
            return true
        }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            statusIcon
                .frame(width: 20)

            // Model info
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))

                HStack(spacing: 6) {
                    if !sizeEstimate.isEmpty {
                        Text(sizeEstimate)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    if isActive {
                        Text("Active")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                    if isBusy {
                        Text(recognizer.pipelineState.statusText)
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    if isError {
                        Text("Error")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }

            Spacer()

            // Action buttons
            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectModel()
        }
    }

    private func selectModel() {
        // If this model is already selected and active/loading, do nothing on tap
        guard model != recognizer.selectedModel || isError else { return }

        // Cancel any in-progress loading before switching
        if recognizer.pipelineState.isBusy {
            recognizer.cancelLoading()
        }

        recognizer.selectedModel = model
        recognizer.isModelLoaded = false
        recognizer.pipelineState = .notStarted
        recognizer.loadModel()
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isActive {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if isBusy {
            ProgressView()
                .controlSize(.small)
        } else if isError {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        } else if isSelected {
            Image(systemName: "circle.dashed")
                .foregroundColor(.orange)
        } else {
            Image(systemName: "arrow.down.circle")
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isActive {
            Button("Reload") {
                recognizer.isModelLoaded = false
                recognizer.pipelineState = .notStarted
                recognizer.loadModel()
            }
            .controlSize(.small)
        } else if isBusy {
            Button("Cancel") {
                recognizer.cancelLoading()
            }
            .controlSize(.small)
            .foregroundColor(.red)
        } else if isError && isSelected {
            Button("Retry") {
                recognizer.loadModel()
            }
            .controlSize(.small)
        } else if isSelected {
            if case .cancelled = recognizer.pipelineState {
                Button("Load") {
                    recognizer.loadModel()
                }
                .controlSize(.small)
            } else {
                Button("Download & Load") {
                    recognizer.loadModel()
                }
                .controlSize(.small)
            }
        } else {
            Text("Select")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Status Banner

private struct ModelsLibraryStatusBanner: View {
    @ObservedObject var recognizer: WhisperRecognizer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch recognizer.pipelineState {
            case .notStarted:
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.secondary)
                    Text("Model not downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Download & Load") {
                        recognizer.loadModel()
                    }
                    .controlSize(.small)
                }

            case .downloading:
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Downloading and loading model...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Cancel") {
                            recognizer.cancelLoading()
                        }
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                    ProgressView()
                        .progressViewStyle(.linear)
                }

            case .downloaded:
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Downloaded, preparing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Cancel") {
                            recognizer.cancelLoading()
                        }
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                    ProgressView()
                        .progressViewStyle(.linear)
                }

            case .loading:
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Loading model into memory...")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Button("Cancel") {
                            recognizer.cancelLoading()
                        }
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                    ProgressView()
                        .progressViewStyle(.linear)
                }

            case .specializing:
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Optimizing for your Mac...")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Button("Cancel") {
                            recognizer.cancelLoading()
                        }
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                    ProgressView()
                        .progressViewStyle(.linear)
                }

            case .ready:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Ready")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                }

            case .error(let msg):
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                    Spacer()
                    Button("Retry") {
                        recognizer.loadModel()
                    }
                    .controlSize(.small)
                }

            case .cancelled:
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                    Text("Loading cancelled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Load") {
                        recognizer.loadModel()
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
    }
}
