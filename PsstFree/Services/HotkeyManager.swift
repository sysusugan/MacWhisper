import Cocoa
import Carbon
import Combine

/// Recording can be in one of three states
enum RecordingState {
    case idle        // Not recording
    case holding     // Recording via hold key (release to stop)
    case toggled     // Recording via toggle (press toggle again or tap hold to stop)
}

class HotkeyManager: ObservableObject {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onRecordingStateChange: ((Bool) -> Void)?
    private var retryTimer: Timer?
    private var hasPromptedUser = false

    @Published var config: HotkeyConfig = .defaultConfig
    @Published var state: RecordingState = .idle
    @Published var accessibilityGranted = false
    @Published var inputMonitoringGranted = false

    func start(config: HotkeyConfig, onStateChange: @escaping (Bool) -> Void) {
        stop()
        self.config = config
        self.onRecordingStateChange = onStateChange

        print("HotkeyManager: Hold='\(config.holdKey.displayString)' Toggle='\(config.toggleCombo.displayString)'")
        print("HotkeyManager: Bundle ID = \(Bundle.main.bundleIdentifier ?? "nil")")
        print("HotkeyManager: Executable path = \(ProcessInfo.processInfo.arguments.first ?? "unknown")")

        setupEventTap()
    }

    /// Open System Settings to Accessibility pane so the user can grant permission.
    /// Unlike AXIsProcessTrustedWithOptions(prompt:true), this doesn't show the
    /// confusing system dialog that keeps reappearing after rebuilds.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Check accessibility and input monitoring status without prompting.
    /// Returns true only if BOTH permissions are granted, since .defaultTap
    /// event taps require both Accessibility and Input Monitoring.
    func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        let listenAccess = CGPreflightListenEventAccess()
        accessibilityGranted = trusted
        inputMonitoringGranted = listenAccess
        return trusted && listenAccess
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        heldKeys.removeAll()
        state = .idle
    }

    func updateConfig(_ newConfig: HotkeyConfig) {
        let callback = onRecordingStateChange
        stop()
        config = newConfig
        if let callback = callback {
            start(config: newConfig, onStateChange: callback)
        }
    }

    // MARK: - CGEvent Tap

    private func setupEventTap() {
        // Preflight check: verify Input Monitoring access before attempting tap creation.
        // This is separate from Accessibility (AXIsProcessTrusted) and is required for
        // CGEvent taps using .defaultTap.
        let hasListenAccess = CGPreflightListenEventAccess()
        inputMonitoringGranted = hasListenAccess
        if !hasListenAccess {
            print("HotkeyManager: Input Monitoring not granted, requesting access")
            CGRequestListenEventAccess()
        }

        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(type: type, event: event)
            },
            userInfo: refcon
        )

        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            retryTimer?.invalidate()
            retryTimer = nil
            accessibilityGranted = true
            inputMonitoringGranted = true
            print("HotkeyManager: Event tap installed successfully")
        } else {
            let trusted = AXIsProcessTrusted()
            let listenAccess = CGPreflightListenEventAccess()
            accessibilityGranted = trusted
            inputMonitoringGranted = listenAccess

            // Log which specific permission is missing so the user knows what to grant
            var missing: [String] = []
            if !trusted { missing.append("Accessibility") }
            if !listenAccess { missing.append("Input Monitoring") }
            let missingStr = missing.isEmpty ? "unknown (both report granted but tap failed)" : missing.joined(separator: " and ")
            print("HotkeyManager: Event tap FAILED — missing permission: \(missingStr) (AXIsProcessTrusted=\(trusted), CGPreflightListenEventAccess=\(listenAccess))")

            if !hasPromptedUser {
                hasPromptedUser = true
                print("HotkeyManager: Opening Accessibility settings for user (missing: \(missingStr))")
                openAccessibilitySettings()
            }

            scheduleRetry()
        }
    }

    /// Retry event tap creation periodically — the user may grant Accessibility
    /// permission while the app is running, so we keep polling.
    private func scheduleRetry() {
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let trusted = AXIsProcessTrusted()
            let listenAccess = CGPreflightListenEventAccess()
            self.accessibilityGranted = trusted
            self.inputMonitoringGranted = listenAccess

            if trusted && listenAccess {
                print("HotkeyManager: Both Accessibility and Input Monitoring now granted, setting up event tap")
                timer.invalidate()
                self.retryTimer = nil
                self.setupEventTap()
            }
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable if system disabled the tap
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Track currently held regular keys
        if type == .keyDown {
            heldKeys.insert(keyCode)
        } else if type == .keyUp {
            heldKeys.remove(keyCode)
        }

        let toggleModsMatch = matchModifiers(flags: flags, target: config.toggleCombo.modifiers)

        // === TOGGLE COMBO (modifier + key) ===
        // Check this FIRST — if hold key is a subset of toggle modifiers,
        // we need to detect the combo before the hold-release logic fires
        if let toggleKey = config.toggleCombo.keyCode {
            if type == .keyDown && keyCode == toggleKey && toggleModsMatch {
                switch state {
                case .idle:
                    transition(to: .toggled)
                    return nil
                case .holding:
                    transition(to: .toggled)
                    return nil
                case .toggled:
                    transition(to: .idle)
                    return nil
                }
            }
        }

        // === HOLD KEY ===

        if config.holdKey.keyCode == nil {
            // Modifier-only hold (e.g. just fn, just ctrl, ctrl+cmd, etc.)
            if type == .flagsChanged {
                let holdActive = isHoldComboActive(flags: flags)
                var consumed = false

                if holdActive {
                    switch state {
                    case .idle:
                        transition(to: .holding)
                        consumed = true
                    case .toggled:
                        holdPressedWhileToggled = true
                        consumed = true
                    case .holding:
                        consumed = true
                    }
                } else {
                    switch state {
                    case .holding:
                        transition(to: .idle)
                        consumed = true
                    case .toggled:
                        if holdPressedWhileToggled {
                            holdPressedWhileToggled = false
                            transition(to: .idle)
                            consumed = true
                        }
                    case .idle:
                        break
                    }
                }

                // Consume the event to prevent system actions (e.g. fn emoji picker)
                if consumed {
                    return nil
                }
            }

        } else {
            // Key-based hold (e.g. hold F5, or ctrl+R, etc.)
            if let holdKey = config.holdKey.keyCode {
                let holdKeyModsMatch = config.holdKey.modifiers.isEmpty || matchModifiers(flags: flags, target: config.holdKey.modifiers)

                if keyCode == holdKey && holdKeyModsMatch {
                    if type == .keyDown {
                        switch state {
                        case .idle:
                            transition(to: .holding)
                            return nil
                        case .toggled:
                            transition(to: .idle)
                            return nil
                        case .holding:
                            break
                        }
                    } else if type == .keyUp {
                        if state == .holding {
                            transition(to: .idle)
                            return nil
                        }
                    }
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    /// Check if the full hold combo is currently active.
    /// For modifier-only combos: exactly the required modifiers must be pressed (no extras).
    /// For key+modifier combos: the key must be in heldKeys and required modifiers must be present.
    private func isHoldComboActive(flags: CGEventFlags) -> Bool {
        if config.holdKey.keyCode == nil {
            // Modifier-only: require exact match so e.g. "fn" alone doesn't trigger
            // when fn+shift is pressed, and vice versa.
            return matchModifiersExact(flags: flags, target: config.holdKey.modifiers)
        }

        // Key+modifier combo: all required modifiers must be present (extras OK)
        let modsMatch = matchModifiers(flags: flags, target: config.holdKey.modifiers)
        if !modsMatch { return false }

        if let holdKeyCode = config.holdKey.keyCode {
            return heldKeys.contains(holdKeyCode)
        }

        return false
    }

    // Set of currently held regular (non-modifier) key codes
    private var heldKeys = Set<UInt16>()

    // For modifier-only hold: detect tap-and-release to stop toggle
    private var holdPressedWhileToggled = false

    /// Check that all required modifiers are present (extras allowed)
    private func matchModifiers(flags: CGEventFlags, target: KeyModifiers) -> Bool {
        if target.fn && !flags.contains(.maskSecondaryFn) { return false }
        if target.option && !flags.contains(.maskAlternate) { return false }
        if target.control && !flags.contains(.maskControl) { return false }
        if target.shift && !flags.contains(.maskShift) { return false }
        if target.command && !flags.contains(.maskCommand) { return false }
        return true
    }

    /// Check that exactly the required modifiers are pressed — no more, no less.
    /// This is used for modifier-only hold keys so that e.g. "fn" alone won't fire
    /// when fn+cmd is pressed (which might be meant for something else).
    private func matchModifiersExact(flags: CGEventFlags, target: KeyModifiers) -> Bool {
        let hasFn = flags.contains(.maskSecondaryFn)
        let hasOption = flags.contains(.maskAlternate)
        let hasControl = flags.contains(.maskControl)
        let hasShift = flags.contains(.maskShift)
        let hasCommand = flags.contains(.maskCommand)

        if target.fn != hasFn { return false }
        if target.option != hasOption { return false }
        if target.control != hasControl { return false }
        if target.shift != hasShift { return false }
        if target.command != hasCommand { return false }
        return true
    }

    /// Transition recording state. Must be called on the main thread because
    /// `@Published` property mutations trigger Combine publishers that SwiftUI
    /// observes on MainActor. This is guaranteed because the CGEvent tap is
    /// added to `CFRunLoopGetMain()`.
    private func transition(to newState: RecordingState) {
        dispatchPrecondition(condition: .onQueue(.main))
        let wasRecording = state != .idle
        let willRecord = newState != .idle
        state = newState

        if wasRecording != willRecord {
            print("HotkeyManager: \(newState) → recording=\(willRecord)")
            DispatchQueue.main.async { [weak self] in
                self?.onRecordingStateChange?(willRecord)
            }
        } else {
            print("HotkeyManager: state → \(newState) (recording unchanged)")
        }
    }

    deinit {
        stop()
    }
}
