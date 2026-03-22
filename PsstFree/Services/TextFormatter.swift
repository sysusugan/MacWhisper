import Foundation
import NaturalLanguage

class TextFormatter {

    // MARK: - Regex Cache (FIX 4)

    private static var regexCache: [String: NSRegularExpression] = [:]
    private static let regexCacheLock = NSLock()

    private static func cachedRegex(pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression? {
        let key = "\(pattern)_\(options.rawValue)"
        regexCacheLock.lock()
        defer { regexCacheLock.unlock() }
        if let cached = regexCache[key] {
            return cached
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        regexCache[key] = regex
        return regex
    }

    // MARK: - Formatting Helpers (FIX 5)

    private func ensureEndingPunctuation(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !trimmed.hasSuffix(".") && !trimmed.hasSuffix("!") && !trimmed.hasSuffix("?") {
            return trimmed + "."
        }
        return trimmed
    }

    private func removeEndingPunctuation(_ text: String) -> String {
        var result = text
        if result.hasSuffix(".") && !result.hasSuffix("...") {
            result = String(result.dropLast())
        }
        return result
    }

    private func capitalizeFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private func lowercaseFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }

    private func capitalizeSentenceStarts(_ text: String) -> String {
        let sentenceEnders: [Character] = [".", "!", "?"]
        var chars = Array(text)

        // Capitalize very first letter
        if let firstIndex = chars.firstIndex(where: { $0.isLetter }) {
            chars[firstIndex] = Character(chars[firstIndex].uppercased())
        }

        for i in 0..<chars.count {
            if sentenceEnders.contains(chars[i]) {
                var j = i + 1
                while j < chars.count && !chars[j].isLetter { j += 1 }
                if j < chars.count {
                    chars[j] = Character(chars[j].uppercased())
                }
            }
        }
        return String(chars)
    }

    /// Apply formatting based on the selected mode
    func format(_ text: String, mode: TranscriptionMode, customModes: [CustomMode]) -> String {
        // First apply vocabulary replacements
        var result = applyVocabularyReplacements(text)

        // Then apply snippet expansions
        result = applySnippetExpansions(result)

        // Then apply basic cleanup
        result = cleanupTranscription(result)

        // Then apply mode-specific formatting
        switch mode {
        case .builtIn(let builtIn):
            result = applyBuiltInMode(result, mode: builtIn)
        case .custom(let id):
            if let customMode = customModes.first(where: { $0.id == id }) {
                result = applyCustomMode(result, mode: customMode)
            }
        }

        // Finally apply writing style
        result = applyWritingStyle(result)

        return result
    }

    // MARK: - Vocabulary (Known Words)

    /// Apply known-words correction: if the transcription contains a case-insensitive
    /// match of a dictionary word, replace it with the correctly-cased version from
    /// the dictionary. This ensures proper nouns and jargon are transcribed correctly.
    private func applyVocabularyReplacements(_ text: String) -> String {
        guard let data = UserDefaults.standard.data(forKey: "vocabularyEntries"),
              let entries = try? JSONDecoder().decode([VocabularyEntry].self, from: data) else {
            return text
        }

        var result = text
        for entry in entries {
            let word = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { continue }

            // Replace any case-insensitive match with the correctly-cased dictionary word
            let escaped = NSRegularExpression.escapedPattern(for: word)
            if let regex = TextFormatter.cachedRegex(pattern: "\\b\(escaped)\\b", options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: NSRegularExpression.escapedTemplate(for: word)
                )
            }
        }

        return result
    }

    // MARK: - Snippet Expansions

    private func applySnippetExpansions(_ text: String) -> String {
        guard let data = UserDefaults.standard.data(forKey: "snippets"),
              let snippets = try? JSONDecoder().decode([Snippet].self, from: data) else {
            return text
        }

        var result = text
        for snippet in snippets {
            let trigger = snippet.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
            let expansion = snippet.expansion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trigger.isEmpty else { continue }

            let escaped = NSRegularExpression.escapedPattern(for: trigger)
            if let regex = TextFormatter.cachedRegex(pattern: "\\b\(escaped)\\b", options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: NSRegularExpression.escapedTemplate(for: expansion)
                )
            }
        }

        return result
    }

    // MARK: - Basic Cleanup

    private func cleanupTranscription(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize first letter
        result = capitalizeFirstLetter(result)

        // Fix common speech-to-text artifacts
        result = fixCommonArtifacts(result)

        // Ensure ending punctuation
        result = ensureEndingPunctuation(result)

        return result
    }

    private func fixCommonArtifacts(_ text: String) -> String {
        var result = text

        // Fix double spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        // Fix space before punctuation
        result = result.replacingOccurrences(of: " .", with: ".")
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " !", with: "!")
        result = result.replacingOccurrences(of: " ?", with: "?")

        // Fix capitalization after sentence-ending punctuation
        result = capitalizeSentenceStarts(result)

        // Handle common dictation phrases (FIX 1)
        // Split into safe (multi-word, unambiguous) and ambiguous (single common words)
        // Safe replacements: multi-word phrases that are unambiguous dictation commands
        let safeReplacements: [String: String] = [
            "exclamation point": "!",
            "exclamation mark": "!",
            "question mark": "?",
            "new line": "\n",
            "new paragraph": "\n\n",
            "open parenthesis": "(",
            "close parenthesis": ")",
            "open bracket": "[",
            "close bracket": "]",
            "at sign": "@",
            "dollar sign": "$",
            "plus sign": "+",
            "equals sign": "=",
        ]

        for (spoken, replacement) in safeReplacements {
            let escaped = NSRegularExpression.escapedPattern(for: spoken)
            if let regex = TextFormatter.cachedRegex(pattern: "\\b\(escaped)\\b", options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
            }
        }

        // Ambiguous single-word replacements: only replace when the word appears as a
        // dictation command — i.e. after a normal word at end of string, OR after a normal
        // word and before a new sentence (next word starts uppercase).
        // This prevents "a period of growth" from becoming "a . of growth".
        let ambiguousReplacements: [String: String] = [
            "period": ".",
            "comma": ",",
            "colon": ":",
            "semicolon": ";",
            "dash": "—",
            "hyphen": "-",
            "slash": "/",
            "backslash": "\\",
            "hashtag": "#",
            "percent": "%",
            "ampersand": "&",
            "asterisk": "*",
            "newline": "\n",
        ]

        for (spoken, replacement) in ambiguousReplacements {
            let escaped = NSRegularExpression.escapedPattern(for: spoken)

            // Case 1: command word at end of string, preceded by a word character + space
            // e.g. "hello period" -> "hello."
            let endPattern = "(?<=\\w)\\s+\(escaped)\\s*$"
            if let regex = TextFormatter.cachedRegex(pattern: endPattern, options: .caseInsensitive) {
                let escapedReplacement = NSRegularExpression.escapedTemplate(for: replacement)
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: escapedReplacement)
            }

            // Case 2: command word mid-sentence, preceded by a word character and followed
            // by a space then an uppercase letter (new sentence after punctuation command)
            // e.g. "hello period How are you" -> "hello. How are you"
            let midPattern = "(?<=\\w)\\s+\(escaped)\\s+(?=[A-Z])"
            if let regex = TextFormatter.cachedRegex(pattern: midPattern, options: []) {
                let escapedReplacement = NSRegularExpression.escapedTemplate(for: replacement + " ")
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: escapedReplacement)
            }
        }

        return result
    }

    // MARK: - Built-in Modes

    private func applyBuiltInMode(_ text: String, mode: TranscriptionMode.BuiltIn) -> String {
        switch mode {
        case .default:
            return text

        case .professional:
            return applyProfessionalMode(text)

        case .casual:
            return applyCasualMode(text)

        case .codeComment:
            return applyCodeCommentMode(text)

        case .bullets:
            return applyBulletsMode(text)
        }
    }

    private func applyProfessionalMode(_ text: String) -> String {
        var result = text

        // Replace informal words with formal equivalents
        let formalReplacements: [String: String] = [
            "\\bgonna\\b": "going to",
            "\\bwanna\\b": "want to",
            "\\bgotta\\b": "have to",
            "\\bkinda\\b": "kind of",
            "\\bsorta\\b": "sort of",
            "\\bdunno\\b": "don't know",
            "\\byeah\\b": "yes",
            "\\bnah\\b": "no",
            "\\bok\\b": "Understood",
            "\\bbtw\\b": "additionally",
            "\\basap\\b": "as soon as possible",
            "\\bfyi\\b": "for your information",
            "\\bimo\\b": "in my opinion",
            "\\bhi\\b": "Hello",
            "\\bhey\\b": "Hello",
            "\\bthanks\\b": "Thank you",
            "\\bthx\\b": "Thank you",
        ]

        for (pattern, replacement) in formalReplacements {
            if let regex = TextFormatter.cachedRegex(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
            }
        }

        return result
    }

    private func applyCasualMode(_ text: String) -> String {
        var result = text

        // Lowercase the first letter if it's not "I" (FIX 2)
        if result.count > 1 {
            let firstChar = result.prefix(1).lowercased()
            let secondChar = result[result.index(result.startIndex, offsetBy: 1)]
            if firstChar != "i" || (secondChar != " " && secondChar != "'") {
                result = firstChar + result.dropFirst()
            }
        }

        // Preserve pronoun "I" throughout text (FIX 2)
        if let iPattern = TextFormatter.cachedRegex(pattern: "(?<=\\s|^)i(?=\\s|'|$)", options: []) {
            result = iPattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "I")
        }

        // Remove trailing period (casual style)
        result = removeEndingPunctuation(result)

        return result
    }

    private func applyCodeCommentMode(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        return lines.map { "// \($0)" }.joined(separator: "\n")
    }

    private func applyBulletsMode(_ text: String) -> String {
        // Split by sentences
        let sentences = splitIntoSentences(text)

        if sentences.count <= 1 {
            return "• \(text)"
        }

        return sentences
            .map { sentence in
                var s = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove trailing period for bullets
                s = removeEndingPunctuation(s)
                return "• \(s)"
            }
            .joined(separator: "\n")
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences.isEmpty ? [text] : sentences
    }

    // MARK: - Writing Style

    private func applyWritingStyle(_ text: String) -> String {
        let styleRaw = UserDefaults.standard.string(forKey: "writingStyle") ?? "formal"
        let style = WritingStyle(rawValue: styleRaw) ?? .formal

        switch style {
        case .formal:
            return applyFormalStyle(text)
        case .casual:
            return applyCasualStyle(text)
        case .veryCasual:
            return applyVeryCasualStyle(text)
        }
    }

    private func applyFormalStyle(_ text: String) -> String {
        var result = capitalizeSentenceStarts(text)

        // Ensure ending punctuation
        result = ensureEndingPunctuation(result)

        return result
    }

    private func applyCasualStyle(_ text: String) -> String {
        var result = capitalizeFirstLetter(text)

        // Remove trailing period if sentence is short (< 10 words)
        let sentences = splitIntoSentences(result)
        if sentences.count <= 1 {
            let wordCount = result.split(separator: " ").count
            if wordCount < 10 {
                result = removeEndingPunctuation(result)
            }
        } else {
            // Process each sentence: remove trailing period on short ones
            var processed: [String] = []
            for sentence in sentences {
                var s = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                let wordCount = s.split(separator: " ").count
                if wordCount < 10 {
                    s = removeEndingPunctuation(s)
                }
                processed.append(s)
            }
            result = processed.joined(separator: " ")
        }

        return result
    }

    private func applyVeryCasualStyle(_ text: String) -> String {
        var result = text.lowercased()

        // Remove trailing period
        result = removeEndingPunctuation(result)

        // Only remove sentence-ending periods (before uppercase — now lowercase after lowercased()),
        // i.e. periods followed by a space and then a letter (which was a sentence boundary).
        // This preserves abbreviation periods like "u.s." (FIX 3)
        if let sentencePeriod = TextFormatter.cachedRegex(pattern: "\\.\\s+(?=[a-z])") {
            result = sentencePeriod.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        }

        return result
    }

    // MARK: - Custom Modes

    private func applyCustomMode(_ text: String, mode: CustomMode) -> String {
        // For custom modes, apply the prompt as a template
        // The prompt can contain {{text}} placeholder
        var result = mode.prompt

        if result.contains("{{text}}") {
            result = result.replacingOccurrences(of: "{{text}}", with: text)
        } else {
            // If no placeholder, just prepend/apply basic transformation
            // Custom modes without templates just return the clean text
            result = text
        }

        return result
    }
}
