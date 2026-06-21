import Foundation
import InsightKit
import JournalStore

/// Fills in derived insights for entries that don't have them yet — new entries
/// and the one-time backfill alike. Runs in the background, low priority, a few
/// entries at a time, so it never competes with the journaling loop. Prefers the
/// Apple-Intelligence extractor when available and falls back to the deterministic
/// NaturalLanguage floor otherwise (invariant #9). Everything is verified against
/// the entry's own words before it's stored.
@MainActor
final class InsightIndexer {
    private let store: any JournalStoring
    private let primary: any EntityExtracting
    private let fallback: any EntityExtracting
    private var isRunning = false

    init(
        store: any JournalStoring,
        primary: any EntityExtracting,
        fallback: any EntityExtracting = NaturalLanguageEntityExtractor()
    ) {
        self.store = store
        self.primary = primary
        self.fallback = fallback
    }

    /// Processes the work queue in small batches until it drains or the task is
    /// cancelled. Safe to call repeatedly; overlapping calls no-op. On the file
    /// fallback the queue is always empty, so this is a quiet no-op there.
    func indexPending(batchSize: Int = 8) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let extractor = await primary.availability().isAvailable ? primary : fallback
        var previousBatch: [UUID] = []

        while !Task.isCancelled {
            let ids = await (try? store.entryIDsNeedingInsights(limit: batchSize)) ?? []
            // Stop when empty, or when a batch repeats — a sign nothing progressed
            // (e.g. a persistent write failure), so we never spin.
            guard !ids.isEmpty, ids != previousBatch else { break }
            previousBatch = ids

            for id in ids {
                guard let entry = try? await store.entry(id: id) else { continue }
                let extractable = ExtractableEntry(id: entry.id, createdAt: entry.createdAt, text: entry.textEdited)
                let raw = await (try? extractor.extract(from: extractable)) ?? .empty
                let verified = InsightVerifier.verified(raw, against: entry.textEdited)
                try? await store.setEntities(Self.entities(from: verified), for: id)
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    /// Flattens verified insights into kinded storage entities (people, places,
    /// objects, topics). Sentiment and action items aren't persisted yet.
    static func entities(from insights: EntryInsights) -> [JournalEntity] {
        insights.people.map { JournalEntity(kind: .person, name: $0) }
            + insights.places.map { JournalEntity(kind: .place, name: $0) }
            + insights.objects.map { JournalEntity(kind: .object, name: $0) }
            + insights.topics.map { JournalEntity(kind: .topic, name: $0) }
    }
}
