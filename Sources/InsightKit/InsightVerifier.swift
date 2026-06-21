import Foundation
import SafetyKit

/// Keeps the model honest: any person / place / object surfaced must actually
/// occur — as a whole word or phrase — in the entry's own text, the same trust
/// guarantee the weekly review enforces on citations. Topics, sentiment, and
/// action items are the model's interpretation and pass through (deduped/trimmed).
public enum InsightVerifier {
    public static func verified(_ insights: EntryInsights, against text: String) -> EntryInsights {
        let normalized = TextNormalizer.normalize(text)

        func present(_ items: [String]) -> [String] {
            deduped(items.filter { TextNormalizer.containsPhrase($0, in: normalized) })
        }

        return EntryInsights(
            people: present(insights.people),
            places: present(insights.places),
            objects: present(insights.objects),
            topics: deduped(insights.topics.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }),
            sentiment: insights.sentiment.flatMap { sentiment in
                let trimmed = sentiment.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            },
            actionItems: deduped(insights.actionItems.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
        )
    }

    /// Case-insensitive dedupe, preserving first-seen order and original casing.
    private static func deduped(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in items {
            let key = item.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(item)
        }
        return result
    }
}
