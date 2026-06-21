import Foundation

/// Shared deterministic text normalization for every lexicon matcher in SafetyKit.
/// Lowercases, strips diacritics, and collapses all non-alphanumerics to single
/// spaces so that hyphenation and punctuation cannot dodge a match. Public so
/// InsightKit can verify extracted entities against the user's own words.
public enum TextNormalizer {
    public static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        let mapped = folded.map { character -> Character in
            character.isLetter || character.isNumber ? character : " "
        }
        return String(mapped)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    /// Whole-word / whole-phrase containment on normalized text.
    public static func containsPhrase(_ phrase: String, in normalizedText: String) -> Bool {
        let needle = " " + normalize(phrase) + " "
        let haystack = " " + normalizedText + " "
        return haystack.contains(needle)
    }
}
