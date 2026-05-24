import SwiftUI
import Cocoa

@main
struct PsstFreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        SettingsRequestHandler.shared.openSettings = {
            SettingsWindowController.shared.open(appState: state)
        }

        if ProcessInfo.processInfo.arguments.contains("--open-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SettingsRequestHandler.shared.open()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.isRecording ? "record.circle.fill" : "mic")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class SettingsRequestHandler {
    static let shared = SettingsRequestHandler()

    var openSettings: (() -> Void)?

    func open() {
        openSettings?()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "psstfree" && $0.host == "settings" }) else { return }
        Task { @MainActor in
            SettingsRequestHandler.shared.open()
        }
    }
}

/// Manages a standalone NSWindow for settings — reliable unlike SwiftUI's Settings scene
/// which doesn't work properly with .menu style MenuBarExtra in SPM builds.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?

    func open(appState: AppState) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(appState)

        let hosting = NSHostingView(rootView: AnyView(settingsView))
        hostingView = hosting

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Psst Free Settings"
        win.contentView = hosting
        win.center()
        win.isReleasedWhenClosed = false
        win.level = .floating  // Ensure it appears above other windows
        window = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Drop from floating to normal after it's visible so it behaves like a regular window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            win.level = .normal
        }
    }
}
