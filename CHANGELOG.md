# Changelog

## [1.0.1] - 2026-03-23

### Improved
- **Models Library redesign** — curated default model list with "Show all" expansion, device-recommended model badge from WhisperKit, tier badges (Best/Balanced/Fast/Compact), and short descriptions for each model
- **Snippet integrity** — snippet expansions are no longer mangled by writing style formatting (capitalization, punctuation removal). Snippets now preserve their exact expansion text regardless of active writing style

### Fixed
- Snippet text getting lowercased or losing punctuation when using Casual or Very Casual writing styles

## [1.0.0] - 2026-03-22

### Added
- Initial release
- On-device speech-to-text via WhisperKit
- Global hotkeys (hold-to-record and toggle mode)
- Auto-paste into frontmost app
- Transcription modes: Default, Professional, Casual, Code Comment, Bullet Points
- Custom modes with prompt templates
- Vocabulary (known words) and snippet expansion
- Writing styles (Formal, Casual, Very Casual)
- Whisper model selection with download management
- Chunked transcription for long recordings
- Recording history with search
