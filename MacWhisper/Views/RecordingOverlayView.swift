import SwiftUI
import Cocoa

// MARK: - Floating Recording Overlay View

struct RecordingOverlayView: View {
    @ObservedObject var levelMonitor: AudioLevelMonitor
    @ObservedObject var hotkeyManager: HotkeyManager

    private var isProcessing: Bool {
        levelMonitor.mode == .processing
    }

    private var isToggleMode: Bool {
        hotkeyManager.state == .toggled
    }

    var body: some View {
        Group {
            if levelMonitor.mode == .modelLoading {
                modelLoadingView
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(loadingPillBackground)
                    .clipShape(Capsule())
            } else {
                ConceptB_FluidWave(
                    audioLevel: levelMonitor.level,
                    isProcessing: isProcessing,
                    isToggleMode: isToggleMode
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: levelMonitor.mode)
    }

    // MARK: - Model Loading

    private var modelLoadingView: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.55)
                .frame(width: 12, height: 12)
            Text("正在加载模型…")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var loadingPillBackground: some View {
        Capsule()
            .fill(Color(nsColor: NSColor(white: 0.11, alpha: 1)))
            .overlay(
                Capsule()
                    .strokeBorder(Color(nsColor: NSColor(white: 0.24, alpha: 1)), lineWidth: 1)
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
        let panelHeight: CGFloat = 80

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
