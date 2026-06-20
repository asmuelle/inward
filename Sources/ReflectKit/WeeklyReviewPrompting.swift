import Foundation

/// Pure helpers shared by the on-device weekly-review provider: how entries are
/// numbered for the model, and how the model's cited numbers map back to real
/// entry ids. Kept free of any platform import so this grounding logic compiles
/// and is unit-testable everywhere, not only where FoundationModels exists.
///
/// The model is shown entries as 1-based numbers rather than UUIDs (which it
/// cannot reproduce reliably). Mapping those numbers back here — dropping any
/// that fall outside the week — is what keeps a hallucinated "[9]" from ever
/// becoming a citation. The pipeline's grounding check is the second line of
/// defense: an observation left with no real ids is rejected.
enum WeeklyReviewPrompting {
    /// The entries listed for the model, each prefixed with the 1-based number it
    /// cites back. This numbering MUST stay in lockstep with `resolve(numbers:in:)`.
    static func entryList(for context: WeekContext) -> String {
        context.entries.enumerated()
            .map { "[\($0.offset + 1)] \($0.element.summary)" }
            .joined(separator: "\n")
    }

    /// Maps 1-based entry numbers from the model to real entry ids: out-of-range
    /// numbers are dropped, duplicates collapsed, original order preserved.
    static func resolve(numbers: [Int], in entries: [ReviewableEntry]) -> [UUID] {
        var seen = Set<UUID>()
        var resolved: [UUID] = []
        for number in numbers {
            let index = number - 1
            guard entries.indices.contains(index) else { continue }
            let id = entries[index].id
            if seen.insert(id).inserted { resolved.append(id) }
        }
        return resolved
    }
}
