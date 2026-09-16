import Foundation

/// Decides whether a timeline search query reads as a question worth asking
/// the entries — a plain heuristic so the "ask" affordance appears exactly when
/// the writer is asking, and stays out of the way of ordinary word search.
public enum QuestionDetector {
    /// A query needs at least this many words before it can be a question; a
    /// lone "why?" has nothing to retrieve on.
    static let minimumWords = 2

    /// Leading words that mark a question in the supported UI languages, so the
    /// affordance works without a trailing question mark.
    static let questionOpeners: Set<String> = [
        // English
        "when", "what", "why", "how", "who", "where", "which", "did", "do", "does",
        "have", "has", "am", "was", "were", "is", "are",
        // German
        "wann", "was", "warum", "wie", "wer", "wo", "welche", "habe", "hatte", "bin", "war",
        // French
        "quand", "pourquoi", "comment", "qui", "où", "quel", "quelle", "est-ce",
        // Spanish / Portuguese / Italian
        "cuándo", "qué", "por", "cómo", "quién", "dónde", "cuál",
        "quando", "porque", "como", "quem", "onde", "qual",
        "perché", "chi", "dove", "quale", "cosa",
        // Scandinavian
        "når", "hva", "hvorfor", "hvordan", "hvem", "hvor",
        "när", "vad", "varför", "hur", "vem", "var",
        "hvad",
        // Russian
        "когда", "что", "почему", "как", "кто", "где", "какой",
    ]

    public static func isQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace)
        guard words.count >= minimumWords else { return false }

        if trimmed.hasSuffix("?") || trimmed.hasSuffix("？") || trimmed.hasPrefix("¿") {
            return true
        }
        let opener = String(words[0]).lowercased().trimmingCharacters(in: .punctuationCharacters)
        return questionOpeners.contains(opener)
    }
}
