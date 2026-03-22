import Foundation

enum TranscriptionMode: Hashable, Identifiable {
    case builtIn(BuiltIn)
    case custom(UUID)

    var id: String {
        switch self {
        case .builtIn(let b): return b.rawValue
        case .custom(let uuid): return uuid.uuidString
        }
    }

    enum BuiltIn: String, CaseIterable, Identifiable {
        case `default` = "default"
        case professional = "professional"
        case casual = "casual"
        case codeComment = "code_comment"
        case bullets = "bullets"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .default: return "Default"
            case .professional: return "Professional"
            case .casual: return "Casual"
            case .codeComment: return "Code Comment"
            case .bullets: return "Bullet Points"
            }
        }

        var description: String {
            switch self {
            case .default: return "Clean transcription with proper punctuation"
            case .professional: return "Formal tone, proper grammar and structure"
            case .casual: return "Relaxed, conversational style"
            case .codeComment: return "Formatted as code comments"
            case .bullets: return "Organized as bullet points"
            }
        }

        var prompt: String {
            switch self {
            case .default: return ""
            case .professional:
                return "Rewrite in a professional, formal tone with proper grammar and structure."
            case .casual:
                return "Rewrite in a casual, conversational tone."
            case .codeComment:
                return "Format as a code comment. Use // prefix for each line."
            case .bullets:
                return "Organize the content as concise bullet points using • prefix."
            }
        }
    }

    static let `default` = TranscriptionMode.builtIn(.default)
}

struct CustomMode: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var prompt: String
    var icon: String

    init(name: String = "New Mode", prompt: String = "", icon: String = "text.bubble") {
        self.id = UUID()
        self.name = name
        self.prompt = prompt
        self.icon = icon
    }
}
