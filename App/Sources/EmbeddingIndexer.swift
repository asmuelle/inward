import Foundation
import JournalStore
import RecallKit

/// Fills in sentence embeddings for entries that don't have one yet — new
/// entries and the one-time backfill alike, mirroring `InsightIndexer`'s
/// batch mechanics. The work queue is store-driven (a missing embedding row);
/// edits drop the row so the entry re-embeds. Runs in the background and never
/// competes with the journaling loop. On the file fallback the queue is always
/// empty, so this is a quiet no-op there.
@MainActor
final class EmbeddingIndexer {
    private let store: any JournalStoring
    private let embedder: any TextEmbedding
    private var isRunning = false

    init(store: any JournalStoring, embedder: any TextEmbedding) {
        self.store = store
        self.embedder = embedder
    }

    func indexPending(batchSize: Int = 16) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        // No model for the user's language — recall stays on the word-overlap
        // floor. Checked here so the loop never spins on a permanent absence.
        guard await embedder.isAvailable() else { return }
        var previousBatch: [UUID] = []

        while !Task.isCancelled {
            let ids = await (try? store.entryIDsNeedingEmbedding(limit: batchSize)) ?? []
            // Stop when empty, or when a batch repeats — a sign nothing
            // progressed (e.g. unembeddable text), so we never spin.
            guard !ids.isEmpty, ids != previousBatch else { break }
            previousBatch = ids

            for id in ids {
                guard let entry = try? await store.entry(id: id) else { continue }
                guard let vector = await embedder.embed(entry.textEdited) else { continue }
                try? await store.setEmbedding(vector, for: id)
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }
}
