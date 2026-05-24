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
            case .default: return "默认"
            case .professional: return "专业"
            case .casual: return "轻松"
            case .codeComment: return "代码注释"
            case .bullets: return "项目符号"
            }
        }

        var description: String {
            switch self {
            case .default: return "干净整洁的转写，带合适的标点"
            case .professional: return "语气正式，语法和结构更规范"
            case .casual: return "更轻松、更口语化的风格"
            case .codeComment: return "按代码注释格式输出"
            case .bullets: return "整理为简洁的项目符号"
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

    init(name: String = "新样式", prompt: String = "", icon: String = "text.bubble") {
        self.id = UUID()
        self.name = name
        self.prompt = prompt
        self.icon = icon
    }
}
