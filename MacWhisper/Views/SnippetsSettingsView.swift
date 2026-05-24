import SwiftUI

// MARK: - Snippet Model

struct Snippet: Codable, Identifiable {
    let id: UUID
    var trigger: String    // what user says
    var expansion: String  // what gets inserted

    init(id: UUID = UUID(), trigger: String = "", expansion: String = "") {
        self.id = id
        self.trigger = trigger
        self.expansion = expansion
    }
}

// MARK: - Snippets Settings View

struct SnippetsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var snippets: [Snippet] = []
    @State private var editingSnippetID: UUID?
    @State private var searchText = ""
    @State private var bannerDismissed = UserDefaults.standard.bool(forKey: "snippetsBannerDismissed")

    private let storageKey = "snippets"

    private var filteredSnippets: [Snippet] {
        if searchText.isEmpty { return snippets }
        let query = searchText.lowercased()
        return snippets.filter {
            $0.trigger.lowercased().contains(query) ||
            $0.expansion.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("片段")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: addSnippet) {
                    Text("新增")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary))
                }
                .buttonStyle(.plain)
            }

            // Hero banner
            if !bannerDismissed {
                heroBanner
            }

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("搜索片段...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))

            // Count
            Text("\(snippets.count) 个片段")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Content
            if filteredSnippets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                        .padding(.top, 24)
                    Text(snippets.isEmpty ? "还没有片段" : "没有匹配的片段")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(snippets.isEmpty ? "点击“新增”来创建文本扩展快捷语。" : "试试别的搜索词。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            } else {
                // Column headers
                HStack(spacing: 8) {
                    Text("触发短语")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("展开为")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: 28)
                }
                .padding(.horizontal, 4)

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredSnippets) { snippet in
                            if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
                                SnippetEntryRow(
                                    snippet: $snippets[index],
                                    isEditing: editingSnippetID == snippet.id,
                                    onTap: { editingSnippetID = snippet.id },
                                    onDelete: { deleteSnippet(snippet.id) },
                                    onCommit: {
                                        editingSnippetID = nil
                                        saveSnippets()
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear { loadSnippets() }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button(action: dismissBanner) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            Text("把那些不该反复手打的内容交给片段。")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Text("把常打的内容保存成可说出的快捷语，比如邮箱、链接、地址、个人介绍等。说出来，应用就会立刻展开。")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2)

            // Example pills
            VStack(alignment: .leading, spacing: 6) {
                examplePill(trigger: "我的邮箱", expansion: "name@example.com")
                examplePill(trigger: "自我介绍", expansion: "你好，很高兴认识你，我目前负责...")
                examplePill(trigger: "预约链接", expansion: "calendly.com/you/invite-name")
            }
            .padding(.top, 4)

            Button(action: addSnippet) {
                Text("新增片段")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.15, blue: 0.55),
                            Color(red: 0.35, green: 0.20, blue: 0.65),
                            Color(red: 0.50, green: 0.25, blue: 0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func examplePill(trigger: String, expansion: String) -> some View {
        HStack(spacing: 6) {
            Text(trigger)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.2)))

            Image(systemName: "arrow.right")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.6))

            Text(expansion)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    // MARK: - Actions

    private func addSnippet() {
        let snippet = Snippet()
        snippets.insert(snippet, at: 0)
        editingSnippetID = snippet.id
        saveSnippets()
    }

    private func deleteSnippet(_ id: UUID) {
        snippets.removeAll { $0.id == id }
        if editingSnippetID == id {
            editingSnippetID = nil
        }
        saveSnippets()
    }

    private func dismissBanner() {
        bannerDismissed = true
        UserDefaults.standard.set(true, forKey: "snippetsBannerDismissed")
    }

    private func loadSnippets() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Snippet].self, from: data) else {
            return
        }
        snippets = decoded
    }

    private func saveSnippets() {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - Snippet Entry Row

private struct SnippetEntryRow: View {
    @Binding var snippet: Snippet
    let isEditing: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onCommit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if isEditing {
                TextField("触发短语", text: $snippet.trigger)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { onCommit() }

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("展开内容...", text: $snippet.expansion)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { onCommit() }

                Button(action: onCommit) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            } else {
                Text(snippet.trigger.isEmpty ? "(空)" : snippet.trigger)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(snippet.trigger.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(snippet.expansion.isEmpty ? "(空)" : snippet.expansion)
                    .font(.system(size: 12))
                    .foregroundColor(snippet.expansion.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
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
