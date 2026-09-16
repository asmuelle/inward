import Foundation

/// Shared accounting for every Foundation Models caller. The published 4K window
/// includes instructions, guided-generation schema, input, and output, so shipped
/// providers receive only this conservative input slice.
public enum ModelPromptBudget {
    public static let contextWindow = 4096
    public static let inputLimit = 2800
    private static let charactersPerToken = 4

    public static func estimateTokens(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return max(1, Int(ceil(Double(text.count) / Double(charactersPerToken))))
    }

    public static func fittingPrefix(_ text: String, maxTokens: Int = inputLimit) -> String {
        guard maxTokens > 0 else { return "" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard estimateTokens(trimmed) > maxTokens else { return trimmed }

        let characterLimit = maxTokens * charactersPerToken
        let boundary = trimmed.index(trimmed.startIndex, offsetBy: min(characterLimit, trimmed.count))
        let prefix = String(trimmed[..<boundary])
        guard let lastWhitespace = prefix.lastIndex(where: \.isWhitespace) else { return prefix }
        return String(prefix[..<lastWhitespace]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
