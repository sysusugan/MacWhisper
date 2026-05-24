import AppKit
import Foundation

enum AppPresentation {
    nonisolated static func desiredActivationPolicy(showInDock: Bool) -> NSApplication.ActivationPolicy {
        showInDock ? .regular : .accessory
    }

    @MainActor
    static func applyCurrentPreference(defaults: UserDefaults = .standard) {
        let showInDock = defaults.bool(forKey: StorageKeys.showInDock)
        NSApp.setActivationPolicy(desiredActivationPolicy(showInDock: showInDock))
    }
}
