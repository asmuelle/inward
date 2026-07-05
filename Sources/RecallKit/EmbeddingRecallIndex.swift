import Accelerate
import Foundation
import JournalStore

/// Semantic recall over stored sentence embeddings: brute-force cosine ranking,
/// entirely in memory. At ~512 dimensions this stays fast well past tens of
/// thousands of entries (vDSP dot products), so a vector index can wait — the
/// surface (`load` / `related`) is what the app builds against, exactly as
/// `NaiveRecallIndex`'s doc promised.
public actor EmbeddingRecallIndex {
    private var vectors: [UUID: [Float]] = [:]
    private let embedder: any TextEmbedding

    public init(embedder: any TextEmbedding) {
        self.embedder = embedder
    }

    /// Replaces the in-memory corpus with the store's current embeddings.
    public func load(_ embeddings: [EntryEmbedding]) {
        vectors = Dictionary(
            embeddings.map { ($0.entryId, $0.vector) },
            uniquingKeysWith: { _, last in last }
        )
    }

    public func indexedCount() -> Int {
        vectors.count
    }

    /// IDs of entries whose text feels like `text`, best match first. Ties break
    /// on UUID string so the order is stable across runs. Empty when the
    /// embedder is unavailable — callers degrade to the word-overlap floor.
    public func related(to text: String, limit: Int = 5, excluding: Set<UUID> = []) async -> [UUID] {
        guard limit > 0, !vectors.isEmpty, let query = await embedder.embed(text) else { return [] }

        var scored: [(id: UUID, score: Float)] = []
        for (id, vector) in vectors where !excluding.contains(id) {
            guard let score = Self.cosine(query, vector), score > 0 else { continue }
            scored.append((id: id, score: score))
        }
        let ranked = scored.sorted { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.id.uuidString < rhs.id.uuidString
        }
        return ranked.prefix(limit).map(\.id)
    }

    /// Cosine similarity via vDSP; nil on dimension mismatch or zero vectors.
    static func cosine(_ lhs: [Float], _ rhs: [Float]) -> Float? {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return nil }
        let dot = vDSP.dot(lhs, rhs)
        let lhsNorm = sqrt(vDSP.dot(lhs, lhs))
        let rhsNorm = sqrt(vDSP.dot(rhs, rhs))
        guard lhsNorm > 0, rhsNorm > 0 else { return nil }
        return dot / (lhsNorm * rhsNorm)
    }
}
