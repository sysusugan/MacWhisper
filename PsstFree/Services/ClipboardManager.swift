import Cocoa
import Foundation

class ClipboardManager {
    /// Copy text to the system clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("ClipboardManager: Copied \(text.count) chars to clipboard")
    }

    /// Read current clipboard contents
    func readClipboard() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    /// Simulate Cmd+V paste into the currently focused application
    func pasteFromClipboard() {
        print("ClipboardManager: Pasting...")

        // Use a fresh event source
        let source = CGEventSource(stateID: .hidSystemState)

        // Virtual key 0x09 = V key
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            print("ClipboardManager: Failed to create CGEvents")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        print("ClipboardManager: Paste events posted")
    }

    /// Copy and paste in one operation, preserving the user's original clipboard contents
    func copyAndPaste(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard contents before overwriting
        let previousContents = pasteboard.string(forType: .string)

        copyToClipboard(text)

        // Give the clipboard time to settle before pasting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.pasteFromClipboard()

            // Restore original clipboard contents after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let previous = previousContents {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                    print("ClipboardManager: Restored original clipboard contents")
                }
            }
        }
    }
}
