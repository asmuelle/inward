import Foundation
import JournalStore

/// Ranks the user's own proper nouns — people and places already extracted from
/// their entries, plus their hand-made tags — into the vocabulary handed to the
/// speech engine for recognition biasing. Pure and Speech-free (mirroring
/// `TranscriptionLocale`) so the ranking tests on any platform; the corpus never
/// leaves memory and is persisted nowhere new.
public enum PersonalLexicon {
    /// Keep the biasing list small and high-signal; hundreds of contextual
    /// strings dilute recognition rather than helping it.
    public static let maxTerms = 100

    /// Most-mentioned people and places first (ties by name for stability), then
    /// tag names not already present. Deduplicates case-insensitively, keeping
    /// the casing the term was first seen with.
    public static func terms(from associations: [EntityAssociation], tags: [Tag]) -> [String] {
        let rankedNames = associations
            .filter { $0.entity.kind == .person || $0.entity.kind == .place }
            .filter { !$0.entryIDs.isEmpty }
            .sorted { lhs, rhs in
                lhs.entryIDs.count != rhs.entryIDs.count
                    ? lhs.entryIDs.count > rhs.entryIDs.count
                    : lhs.entity.name.localizedCaseInsensitiveCompare(rhs.entity.name) == .orderedAscending
            }
            .map(\.entity.name)

        var seen = Set<String>()
        var terms: [String] = []
        for name in rankedNames + tags.map(\.name) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2, seen.insert(trimmed.lowercased()).inserted else { continue }
            terms.append(trimmed)
            if terms.count == maxTerms { break }
        }
        return terms
    }
}
