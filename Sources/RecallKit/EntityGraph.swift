import Foundation
import JournalStore

/// A cross-journal graph of extracted entities: nodes weighted by how often each
/// entity is mentioned, edges by how many entries two entities share. Every node
/// keeps its `entryIDs`, so the mind map can always point back at the user's own
/// entries — the same trust property as cited weekly-review themes.
public struct EntityGraph: Sendable, Equatable {
    public struct Node: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let kind: EntityKind
        public let name: String
        public let mentionCount: Int
        public let entryIDs: [UUID]
    }

    public struct Edge: Sendable, Equatable, Identifiable {
        /// Stable id from the two endpoints (sorted), so the edge is order-independent.
        public let id: String
        public let a: UUID
        public let b: UUID
        public let weight: Int
    }

    public let nodes: [Node]
    public let edges: [Edge]

    public static let empty = EntityGraph(nodes: [], edges: [])

    public var isEmpty: Bool {
        nodes.isEmpty
    }
}

/// Pure, deterministic aggregation of stored entity associations into a graph.
/// No I/O — `JournalStoring.entityAssociations()` supplies the input, so this is
/// fully unit-testable.
public enum EntityGraphBuilder {
    /// Builds the graph, keeping the `topN` most-mentioned entities (ties broken by
    /// name for stability) and the co-occurrence edges among them.
    public static func build(from associations: [EntityAssociation], topN: Int = 60) -> EntityGraph {
        let allNodes: [EntityGraph.Node] = associations.compactMap { association in
            let count = association.entryIDs.count
            guard count > 0 else { return nil }
            return EntityGraph.Node(
                id: association.entity.id,
                kind: association.entity.kind,
                name: association.entity.name,
                mentionCount: count,
                entryIDs: association.entryIDs
            )
        }
        let sortedNodes = allNodes.sorted { lhs, rhs in
            if lhs.mentionCount != rhs.mentionCount {
                return lhs.mentionCount > rhs.mentionCount
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        let kept = Array(sortedNodes.prefix(max(0, topN)))
        var edges: [EntityGraph.Edge] = []
        for i in kept.indices {
            let entriesI = Set(kept[i].entryIDs)
            for j in (i + 1) ..< kept.count {
                let shared = entriesI.intersection(kept[j].entryIDs).count
                guard shared > 0 else { continue }
                let (first, second) = kept[i].id.uuidString < kept[j].id.uuidString
                    ? (kept[i].id, kept[j].id)
                    : (kept[j].id, kept[i].id)
                edges.append(EntityGraph.Edge(
                    id: "\(first.uuidString)|\(second.uuidString)",
                    a: first,
                    b: second,
                    weight: shared
                ))
            }
        }
        return EntityGraph(nodes: kept, edges: edges)
    }
}
