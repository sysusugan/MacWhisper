import SwiftUI

struct ModelsLibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAllModels = false

    /// Models we surface by default — best balance of quality, speed, and size.
    private static let curatedModels: [String] = [
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("模型库")
                .font(.title2)
                .fontWeight(.semibold)

            Text("选择用于转写的 Whisper 模型。模型越大通常越准确，但会占用更多内存且速度更慢。")
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
                                Text(showAllModels ? "收起部分模型" : "显示全部 \(allModels.count) 个模型")
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
        case best = "最佳"
        case balanced = "均衡"
        case fast = "快速"
        case compact = "轻量"
    }

    private func modelInfo(_ model: String) -> ModelInfo {
        let displayName = model
            .replacingOccurrences(of: "openai_whisper-", with: "")
            .replacingOccurrences(of: "distil-whisper_distil-", with: "distil-")

        let lower = model.lowercased()

        if lower.contains("large-v3-v20240930") && lower.contains("turbo") {
            return ModelInfo(displayName: displayName, size: "~800 MB", description: "最新 Turbo，兼顾最佳质量与速度", tier: .best)
        }
        if lower.contains("large-v3") && lower.contains("turbo") && !lower.contains("distil") {
            return ModelInfo(displayName: displayName, size: "~800 MB", description: "速度快，准确率高", tier: .best)
        }
        if lower.contains("distil") && lower.contains("large") && lower.contains("turbo") {
            return ModelInfo(displayName: displayName, size: "~800 MB", description: "蒸馏 Turbo，针对英文优化", tier: .balanced)
        }
        if lower.contains("large-v3") && !lower.contains("turbo") {
            return ModelInfo(displayName: displayName, size: "~3 GB", description: "准确率最高，但速度较慢", tier: .best)
        }
        if lower.contains("distil") && lower.contains("large") {
            return ModelInfo(displayName: displayName, size: "~800 MB", description: "蒸馏版本，针对英文优化", tier: .balanced)
        }
        if lower.contains("medium") && lower.contains(".en") {
            return ModelInfo(displayName: displayName, size: "~1.5 GB", description: "准确率不错，仅限英文", tier: .balanced)
        }
        if lower.contains("medium") {
            return ModelInfo(displayName: displayName, size: "~1.5 GB", description: "准确率不错，支持多语言", tier: .balanced)
        }
        if lower.contains("small") && lower.contains(".en") {
            return ModelInfo(displayName: displayName, size: "~460 MB", description: "较轻量，仅限英文", tier: .fast)
        }
        if lower.contains("small") {
            return ModelInfo(displayName: displayName, size: "~460 MB", description: "较轻量，支持多语言", tier: .fast)
        }
        if lower.contains("base") && lower.contains(".en") {
            return ModelInfo(displayName: displayName, size: "~140 MB", description: "占用极小，仅限英文", tier: .compact)
        }
        if lower.contains("base") {
            return ModelInfo(displayName: displayName, size: "~140 MB", description: "占用极小，支持多语言", tier: .compact)
        }
        if lower.contains("tiny") && lower.contains(".en") {
            return ModelInfo(displayName: displayName, size: "~75 MB", description: "速度最快，基础准确率", tier: .compact)
        }
        if lower.contains("tiny") {
            return ModelInfo(displayName: displayName, size: "~75 MB", description: "速度最快，基础准确率", tier: .compact)
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
                        Text("推荐")
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
                        Text("当前使用")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                    if isBusy {
                        Text(recognizer.pipelineState.statusText)
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    if isError {
                        Text("错误")
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
            Button("重新加载") {
                recognizer.isModelLoaded = false
                recognizer.pipelineState = .notStarted
                recognizer.loadModel()
            }
            .controlSize(.small)
        } else if isBusy {
            Button("取消") {
                recognizer.cancelLoading()
            }
            .controlSize(.small)
            .foregroundColor(.red)
        } else if isError && isSelected {
            Button("重试") {
                recognizer.loadModel()
            }
            .controlSize(.small)
        } else if isSelected {
            if case .cancelled = recognizer.pipelineState {
                Button("加载") {
                    recognizer.loadModel()
                }
                .controlSize(.small)
            } else {
                Button("下载并加载") {
                    recognizer.loadModel()
                }
                .controlSize(.small)
            }
        } else {
            Text("选择")
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
                    Text("模型未下载")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("下载并加载") {
                        recognizer.loadModel()
                    }
                    .controlSize(.small)
                }

            case .downloading:
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("正在下载并加载模型...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("取消") {
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
                        Text("已下载，正在准备...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("取消") {
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
                        Text("正在将模型加载到内存...")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Button("取消") {
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
                        Text("正在为你的 Mac 优化...")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Button("取消") {
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
                    Text("已就绪")
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
                    Button("重试") {
                        recognizer.loadModel()
                    }
                    .controlSize(.small)
                }

            case .cancelled:
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                    Text("已取消加载")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("加载") {
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
