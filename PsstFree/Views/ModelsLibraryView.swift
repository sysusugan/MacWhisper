import SwiftUI

struct ModelsLibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAllModels = false

    /// Models we surface by default — best balance of quality, speed, and size.
    private static let curatedModels: [String] = [
        "openai_whisper-large-v3-v20240930_turbo",
        "openai_whisper-large-v3_turbo",
        "distil-whisper_distil-large-v3_turbo",
        "openai_whisper-small.en",
        "openai_whisper-base.en",
        "openai_whisper-tiny.en",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Models Library")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Select a Whisper model for transcription. Larger models are more accurate but use more memory and are slower.")
                .font(.caption)
                .foregroundColor(.secondary)

            ModelsLibraryStatusBanner(recognizer: appState.whisperRecognizer)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(displayedModels, id: \.self) { model in
                        ModelRow(
                            model: model,
                            info: modelInfo(model),
                            isSelected: model == appState.whisperRecognizer.selectedModel,
                            isRecommended: model == appState.whisperRecognizer.recommendedModel,
                            recognizer: appState.whisperRecognizer
                        )
                    }

                    if hasMoreModels {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllModels.toggle()
                            }
                        } label: {
                            HStack {
                                Text(showAllModels ? "Show fewer models" : "Show all \(allModels.count) models")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: showAllModels ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            appState.whisperRecognizer.fetchAvailableModels()
        }
    }

    private var allModels: [String] {
        if !appState.whisperRecognizer.availableModels.isEmpty {
            return appState.whisperRecognizer.availableModels
        }
        return WhisperRecognizer.defaultModelList
    }

    private var displayedModels: [String] {
        if showAllModels {
            return allModels
        }
        // Show curated models (intersected with available), keeping curated order
        let available = Set(allModels)
        var result = Self.curatedModels.filter { available.contains($0) }
        // Always include the currently selected model even if not curated
        let selected = appState.whisperRecognizer.selectedModel
        if !result.contains(selected) && available.contains(selected) {
            result.append(selected)
        }
        return result
    }

    private var hasMoreModels: Bool {
        displayedModels.count < allModels.count || showAllModels
    }

    // MARK: - Model Metadata

    struct ModelInfo {
        let displayName: String
        let size: String
        let description: String
        let tier: ModelTier
    }

    enum ModelTier: String {
        case best = "Best"
        case balanced = "Balanced"
        case fast = "Fast"
        case compact = "Compact"
    }

    private func modelInfo(_ model: String) -> ModelInfo {
        let displayName = model
            .replacingOccurrences(of: "openai_whisper-", with: "")
            .replacingOccurrences(of: "distil-whisper_distil-", with: "distil-")

        let lower = model.lowercased()

        if lower.contains("large-v3-v20240930") && lower.contains("turbo") {
            return ModelInfo(displayName: displayName, size: "~800 MB", description: "Latest turbo, best quality + speed", tier: .best)
        }
        if lower.contains("large-v3") && lower.contains("turbo") && !lower.contains("distil") {
            return ModelInfo(displayName: displayName, size: "~800 MB", description: "Fast, high accuracy", tier: .best)
        }
        if lower.contains("distil") && lower.contains("large") && lower.contains("turbo") {
            return ModelInfo(displayName: displayName, size: "~800 MB", description: "Distilled turbo, English optimized", tier: .balanced)
        }
        if lower.contains("large-v3") && !lower.contains("turbo") {
            return ModelInfo(displayName: displayName, size: "~3 GB", description: "Highest accuracy, slower", tier: .best)
        }
        if lower.contains("distil") && lower.contains("large") {
            return ModelInfo(displayName: displayName, size: "~800 MB", description: "Distilled, English optimized", tier: .balanced)
        }
        if lower.contains("medium") && lower.contains(".en") {
            return ModelInfo(displayName: displayName, size: "~1.5 GB", description: "Good accuracy, English only", tier: .balanced)
        }
        if lower.contains("medium") {
            return ModelInfo(displayName: displayName, size: "~1.5 GB", description: "Good accuracy, multilingual", tier: .balanced)
        }
        if lower.contains("small") && lower.contains(".en") {
            return ModelInfo(displayName: displayName, size: "~460 MB", description: "Lightweight, English only", tier: .fast)
        }
        if lower.contains("small") {
            return ModelInfo(displayName: displayName, size: "~460 MB", description: "Lightweight, multilingual", tier: .fast)
        }
        if lower.contains("base") && lower.contains(".en") {
            return ModelInfo(displayName: displayName, size: "~140 MB", description: "Minimal footprint, English only", tier: .compact)
        }
        if lower.contains("base") {
            return ModelInfo(displayName: displayName, size: "~140 MB", description: "Minimal footprint, multilingual", tier: .compact)
        }
        if lower.contains("tiny") && lower.contains(".en") {
            return ModelInfo(displayName: displayName, size: "~75 MB", description: "Fastest, basic accuracy", tier: .compact)
        }
        if lower.contains("tiny") {
            return ModelInfo(displayName: displayName, size: "~75 MB", description: "Fastest, basic accuracy", tier: .compact)
        }
        return ModelInfo(displayName: displayName, size: "", description: "", tier: .balanced)
    }
}

// MARK: - Model Row

private struct ModelRow: View {
    let model: String
    let info: ModelsLibraryView.ModelInfo
    let isSelected: Bool
    let isRecommended: Bool
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
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(info.displayName)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))

                    if isRecommended {
                        Text("Recommended")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                    }

                    tierBadge
                }

                HStack(spacing: 6) {
                    if !info.size.isEmpty {
                        Text(info.size)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    if !info.description.isEmpty {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(info.description)
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

    @ViewBuilder
    private var tierBadge: some View {
        if !isRecommended {
            let color: Color = {
                switch info.tier {
                case .best: return .orange
                case .balanced: return .blue
                case .fast: return .green
                case .compact: return .purple
                }
            }()
            Text(info.tier.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(color.opacity(0.12)))
        }
    }

    private func selectModel() {
        guard model != recognizer.selectedModel || isError else { return }

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
