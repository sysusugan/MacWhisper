import SwiftUI
import UniformTypeIdentifiers

struct VocabularyEntry: Codable, Identifiable {
    let id: UUID
    var word: String

    init(id: UUID = UUID(), word: String = "") {
        self.id = id
        self.word = word
    }
}

struct VocabularySettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var entries: [VocabularyEntry] = []
    @State private var editingEntryID: UUID?
    @State private var searchText: String = ""
    @AppStorage("dictionaryBannerDismissed") private var bannerDismissed: Bool = false

    private let storageKey = "vocabularyEntries"

    private var filteredEntries: [VocabularyEntry] {
        if searchText.isEmpty { return entries }
        let query = searchText.lowercased()
        return entries.filter { $0.word.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("词库")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: addEntry) {
                    Label("新增", systemImage: "plus")
                }
                .controlSize(.small)
            }

            // Hero banner
            if !bannerDismissed {
                heroBanner
            }

            // Count + import/export
            HStack {
                Text("\(entries.count) 个词条")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: importEntries) {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
                .controlSize(.small)

                Button(action: exportEntries) {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .controlSize(.small)
                .disabled(entries.isEmpty)
            }

            // Search
            if !entries.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("搜索词条...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15), lineWidth: 1))
            }

            Divider()

            if entries.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("还没有词条")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("点击“新增”来添加你希望应用识别的词。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("没有找到“\(searchText)”")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach($entries) { $entry in
                            if filteredEntries.contains(where: { $0.id == entry.id }) {
                                DictionaryWordRow(
                                    entry: $entry,
                                    isEditing: editingEntryID == entry.id,
                                    onTap: { editingEntryID = entry.id },
                                    onDelete: { deleteEntry(entry.id) },
                                    onCommit: {
                                        editingEntryID = nil
                                        saveEntries()
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear { loadEntries() }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Label("个人词库", systemImage: "text.book.closed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text("让应用更懂你的表达方式。你可以添加个人术语、公司名、客户名或行业黑话。")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                // Example pills
                HStack(spacing: 6) {
                    ForEach(["Anthropic", "Kubernetes", "OAuth", "Figma", "JIRA"], id: \.self) { example in
                        Text(example)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.2)))
                    }
                }

                Button(action: addEntry) {
                    Label("新增词条", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                }
                .buttonStyle(.plain)
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

    // MARK: - Actions

    private func addEntry() {
        let entry = VocabularyEntry()
        entries.append(entry)
        editingEntryID = entry.id
        saveEntries()
    }

    private func deleteEntry(_ id: UUID) {
        entries.removeAll { $0.id == id }
        if editingEntryID == id {
            editingEntryID = nil
        }
        saveEntries()
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([VocabularyEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func exportEntries() {
        guard let data = try? JSONEncoder().encode(entries),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        let panel = NSSavePanel()
        panel.title = "导出词库"
        panel.nameFieldStringValue = "dictionary.json"
        panel.allowedContentTypes = [.json]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? jsonString.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func importEntries() {
        let panel = NSOpenPanel()
        panel.title = "导入词库"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let data = try? Data(contentsOf: url),
                  let imported = try? JSONDecoder().decode([VocabularyEntry].self, from: data) else { return }

            DispatchQueue.main.async {
                let existingWords = Set(entries.map { $0.word.lowercased() })
                for entry in imported {
                    if !existingWords.contains(entry.word.lowercased()) {
                        entries.append(entry)
                    }
                }
                saveEntries()
            }
        }
    }
}

// MARK: - Word Row

private struct DictionaryWordRow: View {
    @Binding var entry: VocabularyEntry
    let isEditing: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onCommit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if isEditing {
                TextField("输入词语或短语", text: $entry.word)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { onCommit() }

                Button(action: onCommit) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            } else {
                Text(entry.word.isEmpty ? "(空)" : entry.word)
                    .font(.system(size: 12))
                    .foregroundColor(entry.word.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 28)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isEditing ? Color.accentColor.opacity(0.06) : Color.gray.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isEditing ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
