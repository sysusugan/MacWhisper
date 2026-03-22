# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Development (stable signing, preserves TCC permissions across rebuilds)
./scripts/setup-dev-cert.sh       # One-time: create self-signed "PsstFree Dev" cert
./scripts/dev-build.sh            # Build debug .app to dist-dev/
./scripts/dev-build.sh --run      # Build and launch

# Release (ad-hoc signing, creates DMG)
./build-app.sh                    # Builds to dist/Psst Free.app + dist/PsstFree-1.0.0.dmg

# Raw swift build
swift build -c debug              # Debug binary to .build/debug/PsstFree
swift build -c release            # Release binary to .build/release/PsstFree

# TCC permission reset (for stale accessibility/input monitoring after rebuilds)
./scripts/reset-tcc.sh            # Reset Accessibility + Input Monitoring + ScreenCapture
./scripts/reset-tcc.sh --all      # Reset ALL TCC categories for com.psst.free
```

No test suite exists. No linter is configured.

## Architecture

**Psst Free** is a macOS menu bar speech-to-text app. It captures microphone audio, transcribes via WhisperKit (on-device), formats the text, and pastes it into the frontmost app.

### Core Data Flow

```
HotkeyManager (global key events via CGEvent tap)
    → AppState.startRecording / stopRecording
        → AudioEngine (AVAudioEngine mic capture, PCM buffers)
        → WhisperRecognizer (WhisperKit transcription)
        → TextFormatter (vocabulary → snippets → cleanup → mode → style)
        → ClipboardManager (NSPasteboard + CGEvent Cmd+V paste)
```

### Key Design Decisions

- **AppState** (`Models/AppState.swift`) is the single `@MainActor ObservableObject` that all views observe. Nested service ObservableObjects forward `objectWillChange` to AppState via Combine.
- **No sandboxing** — required for CGEvent tap (global hotkeys), CGEvent posting (paste automation), and system clipboard access.
- **Menu bar only** — `LSUIElement=true` in Info.plist. Uses `MenuBarExtra` with `.menu` style. Settings window is a standalone `NSWindowController`, not a SwiftUI Scene.
- **Two recording modes**: hold-to-record (release stops) and toggle (press to start, press again to stop). Both managed by `HotkeyManager` via a single CGEvent tap with `.defaultTap` (can consume events).
- **Thread safety**: `AudioSampleBuffer` uses `NSLock` for audio thread → main actor buffer handoff. WhisperKit model loading runs on detached tasks.
- **Permissions**: Requires Accessibility + Input Monitoring (for CGEvent tap) and Microphone. `HotkeyManager` polls every 2s until both are granted, opens System Settings on first failure.

### Services

| Service | Role |
|---------|------|
| `AudioEngine` | AVAudioEngine wrapper, delivers PCM float buffers via callback |
| `WhisperRecognizer` | WhisperKit wrapper, model download/loading, partial + final transcription |
| `HotkeyManager` | CGEvent tap on main run loop, hold/toggle state machine, accessibility checks |
| `ClipboardManager` | NSPasteboard copy + CGEvent Cmd+V paste automation |
| `TextFormatter` | Multi-stage pipeline: vocabulary replacements → snippet expansion → cleanup → mode formatting → writing style |

### Models

- `TranscriptionMode` — enum with `.builtIn(BuiltIn)` (5 presets) and `.custom(UUID)`. Custom modes have a prompt template with `{{text}}` placeholder.
- `HotkeyConfig` — holds `KeyCombo` for hold key and toggle combo. `KeyCombo` has optional keyCode + `KeyModifiers` (control/option/shift/command/fn).
- `StorageKeys` — static string constants for all UserDefaults keys.

### Persistence

All settings stored in `UserDefaults`. No database. AppState loads on init, saves on change. Views use `@AppStorage` for reactive bindings.

## Dependencies

- **WhisperKit** (≥0.9.0) — on-device speech recognition
- **AVFoundation** — audio capture
- **Carbon** — CGEvent tap for global hotkeys
- **NaturalLanguage** — sentence tokenization for bullet formatting

Bundle ID: `com.psst.free` | Platform: macOS 14+
