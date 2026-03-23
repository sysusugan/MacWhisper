import SwiftUI
import AVFoundation

// MARK: - Sidebar Tab Enum

enum SettingsTab: String, CaseIterable {
    case home, vocabulary, snippets, style, scratchpad, configuration, sound, models, history

    var label: String {
        switch self {
        case .home: return "Home"
        case .vocabulary: return "Dictionary"
        case .snippets: return "Snippets"
        case .style: return "Styles"
        case .scratchpad: return "Scratchpad"
        case .configuration: return "Configuration"
        case .sound: return "Sound"
        case .models: return "Models"
        case .history: return "History"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .vocabulary: return "character.book.closed.fill"
        case .snippets: return "scissors"
        case .style: return "textformat"
        case .scratchpad: return "doc.text.fill"
        case .configuration: return "gearshape.fill"
        case .sound: return "speaker.wave.2.fill"
        case .models: return "building.columns.fill"
        case .history: return "clock.fill"
        }
    }
}

// MARK: - Settings View (Sidebar Layout)

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SettingsTab = .home

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SidebarRow(tab: tab, isSelected: selectedTab == tab)
                        .onTapGesture { selectedTab = tab }
                }

                Spacer()

                Text("Psst Free")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .padding(.top, 12)
            .frame(width: 200)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))

            Divider()

            // Content — .environmentObject propagates from the parent SettingsView
            Group {
                switch selectedTab {
                case .home:
                    HomeSettingsTab(selectedTab: $selectedTab)
                case .vocabulary:
                    VocabularySettingsView()
                case .snippets:
                    SnippetsSettingsView()
                case .style:
                    StyleSettingsView()
                case .scratchpad:
                    ScratchpadSettingsView()
                case .configuration:
                    ConfigurationSettingsView()
                case .sound:
                    SoundSettingsView()
                case .models:
                    ModelsLibraryView()
                case .history:
                    HistorySettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 820, height: 580)
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let tab: SettingsTab
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.icon)
                .font(.system(size: 14))
                .frame(width: 20, alignment: .center)
                .foregroundColor(isSelected ? .accentColor : .secondary)
            Text(tab.label)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .primary : .secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Home Tab

struct HomeSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: SettingsTab
    @State private var microphoneName: String = "MacBook Pro Microphone"
    @State private var recentTranscriptions: [TranscriptionRecord] = []

    private var hasHistory: Bool {
        !recentTranscriptions.isEmpty
    }

    private var groupedTranscriptions: [(String, [TranscriptionRecord])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        let grouped = Dictionary(grouping: recentTranscriptions) { record in
            formatter.string(from: record.date).uppercased()
        }
        return grouped.sorted { a, b in
            guard let dateA = recentTranscriptions.first(where: { formatter.string(from: $0.date).uppercased() == a.key }),
                  let dateB = recentTranscriptions.first(where: { formatter.string(from: $0.date).uppercased() == b.key }) else {
                return a.key > b.key
            }
            return dateA.date > dateB.date
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Welcome back")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                if hasHistory {
                    // Timeline of recent transcriptions
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(groupedTranscriptions.enumerated()), id: \.offset) { groupIndex, group in
                            // Date header
                            Text(group.0)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                                .padding(.horizontal, 16)
                                .padding(.top, groupIndex == 0 ? 12 : 20)
                                .padding(.bottom, 8)

                            // Entries for this date
                            ForEach(Array(group.1.enumerated()), id: \.element.id) { entryIndex, record in
                                VStack(spacing: 0) {
                                    if entryIndex > 0 {
                                        Divider()
                                            .padding(.leading, 80)
                                    }
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(timeString(from: record.date))
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .frame(width: 64, alignment: .trailing)

                                        Text(record.text)
                                            .font(.system(size: 13))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                } else {
                    // Get started section (shown when no history)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Get started")
                            .font(.system(size: 15, weight: .semibold))

                        GetStartedCard(
                            icon: "record.circle",
                            title: "Start recording",
                            subtitle: "Turn your voice to text with a single click.",
                            trailing: shortcutBadge
                        )
                        .onTapGesture {
                            appState.isRecording = true
                        }

                        GetStartedCard(
                            icon: "keyboard",
                            title: "Customize your shortcuts",
                            subtitle: "Change the keyboard shortcuts for Psst."
                        )
                        .onTapGesture {
                            selectedTab = .configuration
                        }

                        GetStartedCard(
                            icon: "textformat",
                            title: "Create a style",
                            subtitle: "Build the perfect style for your workflow."
                        )
                        .onTapGesture {
                            selectedTab = .style
                        }

                        GetStartedCard(
                            icon: "text.book.closed",
                            title: "Add vocabulary",
                            subtitle: "Teach Psst custom words, names, or industry terms."
                        )
                        .onTapGesture {
                            selectedTab = .vocabulary
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            loadMicrophoneName()
            loadTranscriptionData()
        }
    }

    @ViewBuilder
    private var shortcutBadge: some View {
        let holdDisplay = appState.hotkeyConfig.holdKey.displayString
        Text(holdDisplay)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.12)))
            .foregroundColor(.secondary)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func loadMicrophoneName() {
        if let device = AVCaptureDevice.default(for: .audio) {
            microphoneName = device.localizedName
        }
    }

    private func loadTranscriptionData() {
        let records = HistorySettingsView.loadHistory()
        guard !records.isEmpty else {
            recentTranscriptions = []
            return
        }

        // Recent transcriptions (last 20, sorted newest first)
        let sorted = records.sorted { $0.date > $1.date }
        recentTranscriptions = Array(sorted.prefix(20))
    }
}

// MARK: - Get Started Card

private struct GetStartedCard<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            trailing

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .contentShape(Rectangle())
    }
}

extension GetStartedCard where Trailing == EmptyView {
    init(icon: String, title: String, subtitle: String) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = EmptyView()
    }
}

