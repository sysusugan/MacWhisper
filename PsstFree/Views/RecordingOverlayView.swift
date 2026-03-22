import SwiftUI
import Cocoa

// MARK: - Floating Recording Overlay View

struct RecordingOverlayView: View {
    @ObservedObject var levelMonitor: AudioLevelMonitor
    @ObservedObject var hotkeyManager: HotkeyManager

    private let dotCount = 5

    private var isToggleMode: Bool {
        hotkeyManager.state == .toggled
    }

    var body: some View {
        Group {
            switch levelMonitor.mode {
            case .recording:
                recordingDots
            case .processing:
                processingDots
            case .modelLoading:
                modelLoadingView
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(pillBackground)
        .animation(.easeInOut(duration: 0.3), value: levelMonitor.mode)
    }

    // MARK: - Recording Dots

    private var recordingDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<dotCount, id: \.self) { index in
                let center = CGFloat(dotCount - 1) / 2.0
                let dist = center > 0 ? abs(CGFloat(index) - center) / center : 0
                let reactivity = 1.0 - dist * 0.4
                let level = CGFloat(levelMonitor.level) * reactivity

                Circle()
                    .fill(.white.opacity(0.8 + Double(level) * 0.2))
                    .frame(width: 5, height: 5)
                    .scaleEffect(1.0 + level * 1.8)
                    .offset(y: -level * 4)
            }
        }
        .animation(.spring(response: 0.1, dampingFraction: 0.6), value: levelMonitor.level)
    }

    // MARK: - Processing Animation (spinning colors)

    private var processingDots: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<dotCount, id: \.self) { index in
                    let phase = (time * 1.2 - Double(index) * 0.2)
                        .truncatingRemainder(dividingBy: 1.0)
                    let hue = phase < 0 ? phase + 1.0 : phase
                    let pulse = 1.0 + 0.25 * sin(time * 3.0 + Double(index) * 1.2)

                    Circle()
                        .fill(Color(hue: hue, saturation: 0.7, brightness: 1.0))
                        .frame(width: 5, height: 5)
                        .scaleEffect(pulse)
                }
            }
        }
    }

    // MARK: - Model Loading

    private var modelLoadingView: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.55)
                .frame(width: 12, height: 12)
            Text("Loading model…")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Background

    private var pillBackground: some View {
        Capsule()
            .fill(Color(nsColor: NSColor(white: 0.11, alpha: 1)))
            .overlay(
                Capsule()
                    .strokeBorder(
                        isToggleMode && levelMonitor.mode == .recording
                            ? Color.red.opacity(0.7)
                            : Color(nsColor: NSColor(white: 0.24, alpha: 1)),
                        lineWidth: isToggleMode && levelMonitor.mode == .recording ? 2 : 1
                    )
            )
            .shadow(
                color: isToggleMode && levelMonitor.mode == .recording
                    ? .red.opacity(0.35) : .black.opacity(0.4),
                radius: isToggleMode && levelMonitor.mode == .recording ? 12 : 8,
                y: isToggleMode && levelMonitor.mode == .recording ? 0 : 3
            )
    }
}

// MARK: - Floating Panel Controller

@MainActor
final class RecordingOverlayController {
    static let shared = RecordingOverlayController()

    private var panel: NSPanel?

    func show(appState: AppState) {
        guard panel == nil else { return }

        let overlayView = RecordingOverlayView(
            levelMonitor: appState.audioLevelMonitor,
            hotkeyManager: appState.hotkeyManager
        )
        let hosting = NSHostingView(rootView: overlayView)

        let panelWidth: CGFloat = 180
        let panelHeight: CGFloat = 60

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        p.ignoresMouseEvents = true
        p.contentView = hosting

        // Center-bottom of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panelWidth / 2
            let y = screenFrame.minY + 30
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel = p
        p.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
