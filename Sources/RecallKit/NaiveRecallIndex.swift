import Foundation

/// M0 placeholder for local retrieval: deterministic word-overlap (Jaccard)
/// ranking, entirely in memory. The sqlite-vec + embedding pipeline replaces the
/// internals later; the surface (`index` / `related`) stays.
public actor NaiveRecallIndex {
    private var documents: [UUID: Set<String>] = [:]

    public init() {}

    public func index(id: UUID, text: String) {
        documents[id] = Self.tokenize(text)
    }

    public func indexedCount() -> Int {
        documents.count
    }

    /// IDs of related documents, best match first. Ties break on UUID string so
    /// the order is stable across runs.
    public func related(to text: String, limit: Int = 5) -> [UUID] {
        let query = Self.tokenize(text)
        guard !query.isEmpty, limit > 0 else { return [] }

        var scored: [(id: UUID, score: Double)] = []
        for (id, tokens) in documents {
            let score = Self.jaccard(query, tokens)
            if score > 0 {
                scored.append((id: id, score: score))
            }
        }
        let ranked = scored.sorted { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.id.uuidString < rhs.id.uuidString
        }
        return ranked.prefix(limit).map(\.id)
    }

    static func tokenize(_ text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count > 2 }
        )
    }

    static func jaccard(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        let intersection = lhs.intersection(rhs).count
        guard intersection > 0 else { return 0 }
        return Double(intersection) / Double(lhs.union(rhs).count)
    }
}
