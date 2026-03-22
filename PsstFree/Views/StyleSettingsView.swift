import SwiftUI

// MARK: - Writing Style Enum

enum WritingStyle: String, CaseIterable {
    case formal = "formal"
    case casual = "casual"
    case veryCasual = "very_casual"

    var displayName: String {
        switch self {
        case .formal: return "Formal."
        case .casual: return "Casual"
        case .veryCasual: return "very casual"
        }
    }

    var description: String {
        switch self {
        case .formal: return "Caps + Punctuation"
        case .casual: return "Caps + Less punctuation"
        case .veryCasual: return "No Caps + Less punctuation"
        }
    }

    var exampleText: String {
        switch self {
        case .formal:
            return "Hey, are you free for lunch tomorrow? Let's do 12 if that works for you."
        case .casual:
            return "Hey, are you free for lunch tomorrow? Let's do 12 if that works for you"
        case .veryCasual:
            return "hey, are you free for lunch tomorrow? let's do 12 if that works for you"
        }
    }

    static func current() -> WritingStyle {
        let raw = UserDefaults.standard.string(forKey: "writingStyle") ?? "formal"
        return WritingStyle(rawValue: raw) ?? .formal
    }
}

// MARK: - Style Settings View (Unified Styles + Custom Styles)

struct StyleSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("writingStyle") private var selectedStyle: String = "formal"
    @AppStorage("styleBannerDismissed") private var bannerDismissed: Bool = false
    @State private var editingMode: CustomMode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Styles")
                    .font(.title2)
                    .fontWeight(.semibold)

                if !bannerDismissed {
                    heroBanner
                }

                // MARK: - Writing Style Cards
                VStack(alignment: .leading, spacing: 8) {
                    Text("Writing Style")
                        .font(.headline)
                    Text("Controls capitalization and punctuation across all transcriptions.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ForEach(WritingStyle.allCases, id: \.self) { style in
                            StyleCard(
                                style: style,
                                isSelected: selectedStyle == style.rawValue,
                                onSelect: { selectedStyle = style.rawValue }
                            )
                        }
                    }
                }

                Divider()

                // MARK: - Built-in Modes (now part of Styles)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Built-in Styles")
                        .font(.headline)

                    VStack(spacing: 0) {
                        ForEach(TranscriptionMode.BuiltIn.allCases) { mode in
                            BuiltInStyleRow(
                                mode: mode,
                                appState: appState,
                                editingMode: $editingMode
                            )
                            if mode != TranscriptionMode.BuiltIn.allCases.last {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.12), lineWidth: 1))
                }

                Divider()

                // MARK: - Custom Styles
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Custom Styles")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            editingMode = CustomMode()
                        }) {
                            Label("Add new", systemImage: "plus")
                        }
                        .controlSize(.small)
                    }

                    if appState.customModes.isEmpty {
                        VStack(spacing: 8) {
                            Text("No custom styles yet. Create one to define your own transcription formatting.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(appState.customModes) { mode in
                                CustomStyleRow(
                                    mode: mode,
                                    appState: appState,
                                    editingMode: $editingMode
                                )
                                if mode.id != appState.customModes.last?.id {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.12), lineWidth: 1))
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .sheet(item: $editingMode) { mode in
            ModeEditorView(mode: mode) { saved in
                if let i = appState.customModes.firstIndex(where: { $0.id == saved.id }) {
                    appState.customModes[i] = saved
                } else {
                    appState.customModes.append(saved)
                }
                appState.saveSettings()
                editingMode = nil
            }
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Styles", systemImage: "textformat")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text("Control how your transcriptions look and feel. Pick a writing style for formatting, choose a built-in style for tone, or create custom styles with your own prompts.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: { bannerDismissed = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Style Card (Writing Style)

private struct StyleCard: View {
    let style: WritingStyle
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(style.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Text(style.description)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Divider()

            Text(style.exampleText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.15), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

// MARK: - Built-in Style Row

private struct BuiltInStyleRow: View {
    let mode: TranscriptionMode.BuiltIn
    @ObservedObject var appState: AppState
    @Binding var editingMode: CustomMode?

    private var isSelected: Bool {
        appState.selectedMode == .builtIn(mode)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForBuiltIn(mode))
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(mode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16))
            }

            Button(action: {
                let duplicate = CustomMode(
                    name: "\(mode.displayName) Copy",
                    prompt: mode.prompt,
                    icon: iconForBuiltIn(mode)
                )
                editingMode = duplicate
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Duplicate as custom style")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedMode = .builtIn(mode)
            appState.saveSettings()
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
    }

    private func iconForBuiltIn(_ mode: TranscriptionMode.BuiltIn) -> String {
        switch mode {
        case .default: return "text.alignleft"
        case .professional: return "briefcase"
        case .casual: return "face.smiling"
        case .codeComment: return "chevron.left.forwardslash.chevron.right"
        case .bullets: return "list.bullet"
        }
    }
}

// MARK: - Custom Style Row

private struct CustomStyleRow: View {
    let mode: CustomMode
    @ObservedObject var appState: AppState
    @Binding var editingMode: CustomMode?

    private var isSelected: Bool {
        appState.selectedMode == .custom(mode.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mode.icon)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.name)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(promptPreview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16))
            }

            Button(action: {
                editingMode = mode
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: {
                if isSelected {
                    appState.selectedMode = .default
                }
                appState.customModes.removeAll { $0.id == mode.id }
                appState.saveSettings()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedMode = .custom(mode.id)
            appState.saveSettings()
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
    }

    private var promptPreview: String {
        if mode.prompt.count > 80 {
            return String(mode.prompt.prefix(80)) + "..."
        }
        return mode.prompt
    }
}
