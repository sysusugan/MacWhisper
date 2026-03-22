import SwiftUI

struct ModeEditorView: View {
    @State var mode: CustomMode
    var onSave: (CustomMode) -> Void
    @Environment(\.dismiss) var dismiss

    let iconOptions = [
        "text.bubble", "doc.text", "envelope", "message",
        "pencil", "highlighter", "bold", "italic",
        "list.bullet", "text.quote", "chevron.left.forwardslash.chevron.right",
        "brain", "sparkles", "wand.and.stars"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text(mode.name.isEmpty ? "New Mode" : "Edit Mode")
                .font(.headline)

            Form {
                TextField("Name", text: $mode.name)

                Picker("Icon", selection: $mode.icon) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Label(icon, systemImage: icon).tag(icon)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt / Template")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $mode.prompt)
                        .font(.body)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    Text("Use {{text}} as placeholder for the transcribed text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)

            // Preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)

                let preview = previewText()
                Text(preview)
                    .font(.callout)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding(.horizontal)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    onSave(mode)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(mode.name.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 400, height: 450)
    }

    func previewText() -> String {
        let sampleText = "Hello this is a sample transcription"
        if mode.prompt.contains("{{text}}") {
            return mode.prompt.replacingOccurrences(of: "{{text}}", with: sampleText)
        } else if mode.prompt.isEmpty {
            return sampleText
        } else {
            return "\(mode.prompt)\n\n\(sampleText)"
        }
    }
}
