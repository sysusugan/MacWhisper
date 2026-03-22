import SwiftUI

private extension DateFormatter {
    static let historyMediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct TranscriptionRecord: Codable, Identifiable {
    let id: UUID
    let text: String
    let date: Date
    let mode: String
}

struct HistorySettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var history: [TranscriptionRecord] = []
    @State private var expandedRecordID: UUID?
    @State private var searchText: String = ""
    @State private var copiedRecordID: UUID?

    private var filteredHistory: [TranscriptionRecord] {
        if searchText.isEmpty {
            return history
        }
        let query = searchText.lowercased()
        return history.filter {
            $0.text.lowercased().contains(query) || $0.mode.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcription History")
                    .font(.headline)
                Spacer()
                if !history.isEmpty {
                    Button(role: .destructive, action: clearHistory) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Clear History")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }

            if !history.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Search transcriptions...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15), lineWidth: 1))
            }

            if history.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No transcriptions yet. Start recording to build your history.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filteredHistory.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No results for \"\(searchText)\"")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredHistory) { record in
                            let isExpanded = expandedRecordID == record.id

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(relativeTimestamp(record.date))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(record.mode)
                                            .font(.caption2)
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(
                                                Capsule()
                                                    .fill(Color.accentColor.opacity(0.1))
                                            )
                                    }

                                    Spacer()

                                    Button(action: {
                                        copyToClipboard(record.text)
                                        copiedRecordID = record.id
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            if copiedRecordID == record.id {
                                                copiedRecordID = nil
                                            }
                                        }
                                    }) {
                                        Image(systemName: copiedRecordID == record.id ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 12))
                                            .foregroundColor(copiedRecordID == record.id ? .green : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy to clipboard")
                                }

                                Text(isExpanded ? record.text : previewText(record.text))
                                    .font(.callout)
                                    .lineLimit(isExpanded ? nil : 2)
                                    .foregroundColor(.primary)

                                if record.text.count > 80 {
                                    Text(isExpanded ? "Show less" : "Show more")
                                        .font(.caption2)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if isExpanded {
                                        expandedRecordID = nil
                                    } else {
                                        expandedRecordID = record.id
                                    }
                                }
                            }

                            if record.id != filteredHistory.last?.id {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.12), lineWidth: 1))
                }
            }
        }
        .padding()
        .onAppear {
            history = HistorySettingsView.loadHistory()
        }
    }

    // MARK: - Helpers

    private func previewText(_ text: String) -> String {
        if text.count <= 80 {
            return text
        }
        return String(text.prefix(80)) + "..."
    }

    private func relativeTimestamp(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return days == 1 ? "Yesterday" : "\(days) days ago"
        } else {
            return DateFormatter.historyMediumDateTime.string(from: date)
        }
    }

    private func copyToClipboard(_ text: String) {
        appState.clipboardManager.copyToClipboard(text)
    }

    private func clearHistory() {
        history = []
        searchText = ""
        expandedRecordID = nil
        HistorySettingsView.saveHistory([])
    }

    // MARK: - Persistence

    static func loadHistory() -> [TranscriptionRecord] {
        guard let data = UserDefaults.standard.data(forKey: "transcriptionHistory"),
              let records = try? JSONDecoder().decode([TranscriptionRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.date > $1.date }
    }

    static func saveHistory(_ records: [TranscriptionRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "transcriptionHistory")
        }
    }

    static func addRecord(text: String, mode: String) {
        var records = loadHistory()
        let record = TranscriptionRecord(id: UUID(), text: text, date: Date(), mode: mode)
        records.insert(record, at: 0)
        // Keep only last 100 records
        if records.count > 100 {
            records = Array(records.prefix(100))
        }
        saveHistory(records)
    }
}
