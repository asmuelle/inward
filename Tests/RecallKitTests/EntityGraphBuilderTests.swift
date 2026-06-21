import Foundation
import JournalStore
@testable import RecallKit
import Testing

private func entity(_ kind: EntityKind, _ name: String) -> JournalEntity {
    JournalEntity(kind: kind, name: name)
}

private let e1 = UUID(uuidString: "00000000-0000-0000-0000-0000000000E1")!
private let e2 = UUID(uuidString: "00000000-0000-0000-0000-0000000000E2")!
private let e3 = UUID(uuidString: "00000000-0000-0000-0000-0000000000E3")!

@Suite("EntityGraphBuilder — entities into a weighted co-occurrence graph")
struct EntityGraphBuilderTests {
    @Test("node weight is the mention count; entries with no mentions are dropped")
    func nodeWeights() {
        let graph = EntityGraphBuilder.build(from: [
            EntityAssociation(entity: entity(.person, "Sarah"), entryIDs: [e1, e2]),
            EntityAssociation(entity: entity(.place, "Berlin"), entryIDs: [e1]),
            EntityAssociation(entity: entity(.topic, "ghost"), entryIDs: []), // dropped
        ])

        #expect(graph.nodes.count == 2)
        #expect(graph.nodes.first?.name == "Sarah") // highest mention count first
        #expect(graph.nodes.first?.mentionCount == 2)
    }

    @Test("an edge links two entities by how many entries they share")
    func coOccurrenceEdges() {
        let graph = EntityGraphBuilder.build(from: [
            EntityAssociation(entity: entity(.person, "Sarah"), entryIDs: [e1, e2, e3]),
            EntityAssociation(entity: entity(.place, "Berlin"), entryIDs: [e1, e2]),
            EntityAssociation(entity: entity(.topic, "mornings"), entryIDs: [e3]),
        ])

        // Sarah & Berlin share e1,e2 → weight 2. Sarah & mornings share e3 → weight 1.
        // Berlin & mornings share nothing → no edge.
        #expect(graph.edges.count == 2)
        let sarahBerlin = graph.edges.first { $0.weight == 2 }
        #expect(sarahBerlin != nil)
        #expect(graph.edges.allSatisfy { $0.weight >= 1 })
    }

    @Test("topN keeps only the most-mentioned nodes, and edges stay within them")
    func topNCap() {
        let associations = (1 ... 5).map { index in
            EntityAssociation(
                entity: entity(.topic, "t\(index)"),
                entryIDs: Array(repeating: UUID(), count: index) // weights 1...5
            )
        }
        let graph = EntityGraphBuilder.build(from: associations, topN: 2)

        #expect(graph.nodes.count == 2)
        #expect(graph.nodes.map(\.name) == ["t5", "t4"]) // top two by weight
    }

    @Test("empty input yields an empty graph")
    func emptyInput() {
        #expect(EntityGraphBuilder.build(from: []) == .empty)
    }
}
