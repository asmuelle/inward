import Foundation
import JournalStore
import RecallKit

/// The app-facing recall surface: timeline search and "entries that feel like
/// this one". Semantic (embedding cosine) when the store has vectors and the
/// language has a model; the deterministic word-overlap floor otherwise — the
/// feature is model-optional like everything else (invariant #9).
@MainActor
@Observable
final class RecallModel {
    private let store: any JournalStoring
    private let semanticIndex: EmbeddingRecallIndex

    init(store: any JournalStoring, embedder: any TextEmbedding) {
        self.store = store
        semanticIndex = EmbeddingRecallIndex(embedder: embedder)
    }

    /// Reloads the in-memory corpus from the store — call after the embedding
    /// indexer runs or entries change.
    func reload() async {
        let embeddings = await (try? store.allEmbeddings()) ?? []
        await semanticIndex.load(embeddings)
    }

    /// Search results for the timeline: literal matches first (verifiable, so
    /// they anchor trust), then semantic neighbors of the query that no
    /// substring would find. Returns `entries` unchanged for an empty query.
    func search(_ query: String, in entries: [Entry]) async -> [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }

        let literal = entries.filter {
            $0.textEdited.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        let literalIDs = Set(literal.map(\.id))
        let byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let semantic = await semanticIndex
            .related(to: trimmed, limit: 10, excluding: literalIDs)
            .compactMap { byID[$0] }
        return literal + semantic
    }

    /// Up to `limit` entries that feel like this one. Embedding neighbors when
    /// available; Jaccard word overlap as the always-on floor.
    func related(to entry: Entry, limit: Int = 3) async -> [Entry] {
        let semanticIDs = await semanticIndex.related(to: entry.textEdited, limit: limit, excluding: [entry.id])
        if !semanticIDs.isEmpty {
            return await entries(for: semanticIDs)
        }

        let all = await (try? store.allEntries()) ?? []
        let floor = NaiveRecallIndex()
        for other in all where other.id != entry.id {
            await floor.index(id: other.id, text: other.textEdited)
        }
        let ids = await floor.related(to: entry.textEdited, limit: limit)
        return ids.compactMap { id in all.first { $0.id == id } }
    }

    private func entries(for ids: [UUID]) async -> [Entry] {
        var found: [Entry] = []
        for id in ids {
            if let entry = try? await store.entry(id: id) {
                found.append(entry)
            }
        }
        return found
    }
}
