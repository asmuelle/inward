import Foundation

/// Conservative token accounting for the 8K on-device context window. Estimation
/// is deliberately pessimistic (≈4 characters per token); chunking splits on
/// sentence boundaries first, whitespace second, so no chunk exceeds the budget.
public enum TokenBudgeter {
    public static let contextWindow = 8192
    static let charactersPerToken = 4

    public static func estimateTokens(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return max(1, Int((Double(text.count) / Double(charactersPerToken)).rounded(.up)))
    }

    /// Splits text into chunks that each fit `maxTokens`. Content is preserved:
    /// joining the chunks with single spaces loses only inter-sentence whitespace.
    public static func chunk(_ text: String, maxTokens: Int) -> [String] {
        precondition(maxTokens > 0, "token budget must be positive")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard estimateTokens(trimmed) > maxTokens else { return [trimmed] }

        let sentences = splitSentences(trimmed)
        var chunks: [String] = []
        var current = ""
        for sentence in sentences {
            let candidate = current.isEmpty ? sentence : current + " " + sentence
            if estimateTokens(candidate) <= maxTokens {
                current = candidate
            } else {
                if !current.isEmpty { chunks.append(current) }
                current = ""
                chunks.append(contentsOf: splitOversized(sentence, maxTokens: maxTokens, into: &current))
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private static func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == "." || character == "!" || character == "?" || character == "\n" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }
        return sentences
    }

    /// Splits a single oversized sentence by words; any remainder that still fits
    /// is handed back via `carry` so following sentences can pack with it.
    private static func splitOversized(_ sentence: String, maxTokens: Int, into carry: inout String) -> [String] {
        var chunks: [String] = []
        var current = ""
        for word in sentence.split(separator: " ") {
            let candidate = current.isEmpty ? String(word) : current + " " + word
            if estimateTokens(candidate) <= maxTokens {
                current = candidate
            } else {
                if !current.isEmpty { chunks.append(current) }
                current = String(word)
            }
        }
        carry = current
        return chunks
    }
}
