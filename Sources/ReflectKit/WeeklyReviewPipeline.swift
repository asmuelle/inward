import Foundation
import SafetyKit

public enum WeeklyReviewOutcome: Sendable, Equatable {
    /// The gate matched on the week's text: static resources only, model never invoked.
    case suppressed(resources: [SupportResource])
    /// A synthesized review whose every observation cites at least one real entry.
    case synthesized(WeeklyReviewDraft)
    /// Synthesis could not be trusted twice running, so the week degrades to
    /// deterministic recurring-theme counts — never fabricated prose.
    case themesOnly([ThemeCount])
    /// Nothing to show: no entries, or the model is unavailable on this device.
    case unavailable
}

/// Weekly review with verified citations — the trust artifact of M2. Like
/// `ReflectionPipeline`, the deterministic crisis gate runs before any model call
/// (invariant #5), and output is validated after (invariants #1 and #7). Here the
/// decisive check is citation grounding: an observation that cites an entry not in
/// the week is rejected, the review is regenerated once, and a second failure
/// falls back to deterministic theme counts rather than ungrounded synthesis.
public struct WeeklyReviewPipeline: Sendable {
    public static let maxObservations = 5
    /// A word must recur across at least this many entries to count as a theme.
    static let minThemeDocumentFrequency = 2
    static let maxThemes = 3
    static let minThemeWordLength = 5

    private let gate: CrisisGate
    private let provider: any WeeklyReviewProviding

    public init(gate: CrisisGate = CrisisGate(), provider: any WeeklyReviewProviding) {
        self.gate = gate
        self.provider = provider
    }

    public func review(for context: WeekContext) async -> WeeklyReviewOutcome {
        guard !context.entries.isEmpty else { return .unavailable }

        let weekText = context.entries.map(\.summary).joined(separator: "\n")
        if case let .matched(_, resources) = gate.evaluate(weekText) {
            return .suppressed(resources: resources)
        }

        guard case .available = await provider.availability() else {
            return .unavailable
        }

        // One synthesis attempt, one regeneration on failure, then the floor.
        for _ in 0 ..< 2 {
            guard let draft = try? await provider.review(for: context),
                  Self.isGrounded(draft, in: context)
            else { continue }
            return .synthesized(draft)
        }

        let themes = Self.recurringThemes(in: context)
        return themes.isEmpty ? .unavailable : .themesOnly(themes)
    }

    /// A draft is shown only if it has at least one observation and every
    /// observation is non-empty, free of regulated vocabulary, and cites only
    /// entries that actually exist in the week.
    static func isGrounded(_ draft: WeeklyReviewDraft, in context: WeekContext) -> Bool {
        guard (1 ... maxObservations).contains(draft.observations.count) else { return false }
        let citable = context.citableIDs

        return draft.observations.allSatisfy { observation in
            let theme = observation.theme.trimmingCharacters(in: .whitespacesAndNewlines)
            let note = observation.note.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !theme.isEmpty, !note.isEmpty else { return false }
            guard !observation.citedEntryIds.isEmpty,
                  observation.citedEntryIds.allSatisfy(citable.contains)
            else { return false }
            return BannedTerms.violations(in: theme).isEmpty
                && BannedTerms.violations(in: note).isEmpty
        }
    }

    /// Deterministic fallback: words recurring across `minThemeDocumentFrequency`+
    /// entries, ranked by how many entries they touch (ties by the word), each
    /// carrying the real entry ids it came from. No model, no prose — auditable counts.
    ///
    /// Public so a surface can show recurring themes even when the model is
    /// unavailable on the device (model-optional journaling, invariant #9).
    public static func recurringThemes(in context: WeekContext) -> [ThemeCount] {
        var entriesByWord: [String: [UUID]] = [:]
        for entry in context.entries {
            for word in tokens(in: entry.summary) where BannedTerms.violations(in: word).isEmpty {
                entriesByWord[word, default: []].append(entry.id)
            }
        }

        return entriesByWord
            .filter { $0.value.count >= minThemeDocumentFrequency }
            .map { ThemeCount(theme: $0.key, count: $0.value.count, entryIds: $0.value.sorted { $0.uuidString < $1.uuidString }) }
            .sorted { lhs, rhs in
                lhs.count != rhs.count ? lhs.count > rhs.count : lhs.theme < rhs.theme
            }
            .prefix(maxThemes)
            .map { $0 }
    }

    /// Distinct lowercased words of a summary, long enough to carry meaning and not
    /// a generic filler. Distinct-per-entry so one entry repeating a word counts
    /// once toward frequency.
    private static func tokens(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count >= minThemeWordLength && !stopwords.contains($0) }
        )
    }

    /// Words that clear the length filter but are too generic to be a theme.
    /// Without this, fillers like "coming", "really", or "things" surface as the
    /// week's theme in the deterministic fallback.
    static let stopwords: Set<String> = [
        "about", "above", "after", "again", "against", "almost", "along", "already",
        "although", "always", "among", "another", "anything", "around", "because",
        "becomes", "before", "behind", "being", "below", "between", "beyond",
        "coming", "could", "doing", "during", "either", "enough", "especially",
        "every", "everyone", "everything", "getting", "going", "gonna", "having",
        "however", "instead", "itself", "least", "little", "maybe", "might", "more",
        "most", "much", "myself", "never", "often", "other", "others", "ourselves",
        "perhaps", "pretty", "probably", "quite", "rather", "really", "right",
        "seems", "should", "since", "somehow", "someone", "something", "sometimes",
        "still", "their", "theirs", "themselves", "there", "these", "thing",
        "things", "think", "thinking", "those", "though", "through", "today",
        "together", "tomorrow", "tonight", "toward", "towards", "under", "until",
        "usually", "very", "what", "whatever", "when", "where", "whether", "which",
        "while", "whole", "will", "with", "within", "without", "would", "yeah",
        "yesterday", "your", "yours", "yourself",
    ]
}
