import SwiftUI
import Combine

private extension DateFormatter {
    static let scratchpadTimeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let scratchpadMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let scratchpadFullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
}

struct ScratchpadNote: Codable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String = "未命名", content: String = "") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct ScratchpadSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var notes: [ScratchpadNote] = []
    @State private var selectedNoteID: UUID?
    @State private var searchText: String = ""
    @State private var editingTitle: String = ""
    @State private var editingContent: String = ""
    @State private var saveTask: DispatchWorkItem?

    private var filteredNotes: [ScratchpadNote] {
        let sorted = notes.sorted { $0.updatedAt > $1.updatedAt }
        if searchText.isEmpty {
            return sorted
        }
        let query = searchText.lowercased()
        return sorted.filter {
            $0.title.lowercased().contains(query) || $0.content.lowercased().contains(query)
        }
    }

    private var selectedNote: ScratchpadNote? {
        guard let id = selectedNoteID else { return nil }
        return notes.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header toolbar
            HStack(spacing: 8) {
                Text("便笺")
                    .font(.headline)

                Spacer()

                Button(action: { /* focus search */ }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("搜索笔记")

                Button(action: createNote) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("新建笔记")

                Button(action: refreshNotes) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("刷新")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if selectedNoteID != nil {
                editorView
            } else {
                listView
            }
        }
        .onAppear {
            notes = ScratchpadSettingsView.loadNotes()
        }
        .onDisappear {
            saveTask?.cancel()
            saveCurrentNote()
        }
    }

    // MARK: - List View

    @ViewBuilder
    private var listView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar
            if !notes.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("搜索笔记...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            if notes.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("还没有笔记。点击 + 新建一条。")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if filteredNotes.isEmpty {
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
                .padding()
            } else {
                // RECENTS label
                Text("最近")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredNotes) { note in
                            noteRow(note)

                            if note.id != filteredNotes.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.12), lineWidth: 1))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func noteRow(_ note: ScratchpadNote) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "未命名" : note.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                if !note.content.isEmpty {
                    Text(previewText(note.content))
                        .font(.system(size: 12))
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                }

                Text(formatNoteDate(note.updatedAt))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()

            Button(action: { deleteNote(note.id) }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("删除笔记")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            selectNote(note)
        }
    }

    // MARK: - Editor View

    @ViewBuilder
    private var editorView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button + title
            HStack(spacing: 8) {
                Button(action: closeEditor) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("返回")
                            .font(.callout)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    if let id = selectedNoteID {
                        deleteNote(id)
                        closeEditor()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("删除笔记")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Title field
            TextField("标题", text: $editingTitle)
                .font(.system(size: 16, weight: .semibold))
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .onChange(of: editingTitle) {
                    debouncedSave()
                }

            Divider()
                .padding(.horizontal, 16)

            // Content editor
            TextEditor(text: $editingContent)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .onChange(of: editingContent) {
                    debouncedSave()
                }

            Spacer(minLength: 0)

            // Footer with date
            if let note = selectedNote {
                HStack {
                    Text("更新于 \(formatNoteDate(note.updatedAt))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
    }

    // MARK: - Actions

    private func createNote() {
        let note = ScratchpadNote()
        notes.insert(note, at: 0)
        ScratchpadSettingsView.saveNotes(notes)
        selectNote(note)
    }

    private func selectNote(_ note: ScratchpadNote) {
        selectedNoteID = note.id
        editingTitle = note.title == "未命名" ? "" : note.title
        editingContent = note.content
    }

    private func closeEditor() {
        saveCurrentNote()
        selectedNoteID = nil
        editingTitle = ""
        editingContent = ""
    }

    private func deleteNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
        ScratchpadSettingsView.saveNotes(notes)
        if selectedNoteID == id {
            selectedNoteID = nil
            editingTitle = ""
            editingContent = ""
        }
    }

    private func refreshNotes() {
        notes = ScratchpadSettingsView.loadNotes()
        if let id = selectedNoteID, let note = notes.first(where: { $0.id == id }) {
            editingTitle = note.title == "未命名" ? "" : note.title
            editingContent = note.content
        }
    }

    private func debouncedSave() {
        saveTask?.cancel()
        let notesToSave = notes
        let currentTitle = editingTitle
        let currentContent = editingContent
        let currentSelectedID = selectedNoteID
        let task = DispatchWorkItem {
            DispatchQueue.main.async {
                guard let id = currentSelectedID,
                      let index = notesToSave.firstIndex(where: { $0.id == id }) else { return }
                var updatedNotes = notesToSave
                let title = currentTitle.isEmpty ? "未命名" : currentTitle
                updatedNotes[index].title = title
                updatedNotes[index].content = currentContent
                updatedNotes[index].updatedAt = Date()
                ScratchpadSettingsView.saveNotes(updatedNotes)
            }
        }
        saveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    private func saveCurrentNote() {
        guard let id = selectedNoteID,
              let index = notes.firstIndex(where: { $0.id == id }) else { return }

        let title = editingTitle.isEmpty ? "未命名" : editingTitle
        notes[index].title = title
        notes[index].content = editingContent
        notes[index].updatedAt = Date()
        ScratchpadSettingsView.saveNotes(notes)
    }

    // MARK: - Helpers

    private func previewText(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "\n", with: " ")
        if cleaned.count <= 100 {
            return cleaned
        }
        return String(cleaned.prefix(100)) + "..."
    }

    private func formatNoteDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return DateFormatter.scratchpadTimeOnly.string(from: date)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return DateFormatter.scratchpadMonthDay.string(from: date)
        } else {
            return DateFormatter.scratchpadFullDate.string(from: date)
        }
    }

    // MARK: - Persistence

    static func loadNotes() -> [ScratchpadNote] {
        guard let data = UserDefaults.standard.data(forKey: "scratchpadNotes"),
              let decoded = try? JSONDecoder().decode([ScratchpadNote].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func saveNotes(_ notes: [ScratchpadNote]) {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: "scratchpadNotes")
        }
    }
}
