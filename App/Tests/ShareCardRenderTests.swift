import DesignSystem
@testable import Inward
import JournalStore
import RecallKit
import ReflectKit
import SwiftUI
import Testing

/// Share cards are the one artefact Inward emits, so "it actually rasterizes" is
/// a shipping requirement, not a detail: a nil render means the share button is
/// silently absent. These live in the simulator-hosted target because SwiftUI
/// declines to rasterize in the headless SPM test process.
@MainActor
@Suite("Share cards — rendering and the rules about what goes in them")
struct ShareCardRenderTests {
    @Test("the proof card renders at the declared 4:5 pixel size, offline and on")
    func proofCardRenders() {
        for isOffline in [true, false] {
            // Act
            let image = ShareCardRenderer.cgImage(ProofShareCard(isOffline: isOffline))

            // Assert
            #expect(image != nil)
            #expect(image?.width == Int(Lamplight.ShareCard.size.width))
            #expect(image?.height == Int(Lamplight.ShareCard.size.height))
        }
    }

    @Test("the themes card renders, and survives an empty week")
    func themesCardRenders() {
        let full = ShareCardRenderer.cgImage(
            ThemesShareCard(themes: ["sleep", "the move", "patience"], dateRange: "18–25 Jul")
        )
        #expect(full?.height == Int(Lamplight.ShareCard.size.height))
        #expect(ShareCardRenderer.cgImage(ThemesShareCard(themes: [], dateRange: "")) != nil)
    }

    @Test("the mind-map card renders from a real graph")
    func mindMapCardRenders() {
        let image = ShareCardRenderer.cgImage(MindMapShareCard(graph: Self.graph(nodeCount: 8)))
        #expect(image?.width == Int(Lamplight.ShareCard.size.width))
    }

    @Test("the mind-map card caps its circles and drops edges to circles it dropped")
    func mindMapCardCapsNodes() {
        // Arrange — more nodes than the card will draw.
        let graph = Self.graph(nodeCount: MindMapShareCard.maxNodes + 12)

        // Act
        let nodes = MindMapShareCard.displayedNodes(graph.nodes)
        let edges = MindMapShareCard.keptEdges(graph.edges, among: nodes)

        // Assert
        #expect(nodes.count == MindMapShareCard.maxNodes)
        let ids = Set(nodes.map(\.id))
        #expect(edges.allSatisfy { ids.contains($0.a) && ids.contains($0.b) })
        // The most-mentioned survive the cap; the long tail is what gets cut.
        #expect(nodes.first?.mentionCount == graph.nodes.map(\.mentionCount).max())
    }

    // MARK: - The privacy rules, asserted rather than assumed

    @Test("the weekly card is offered only where there are theme words to picture")
    func themesAreOfferedOnlyWhenTheyExist() {
        #expect(ThemesShareCard.displayed(["sleep", "patience"]).isEmpty == false)
        #expect(ThemesShareCard.displayed([]).isEmpty)
        #expect(ThemesShareCard.displayed(["   "]).isEmpty)
    }

    /// The mind map holds other people's names. The picture must not. The card
    /// reduces the graph to geometry in `init`, so this asserts the reduction
    /// really happened — no name survives anywhere in what the card holds.
    @Test("no node name survives into the mind-map card")
    func mindMapCardCarriesNoNames() {
        let graph = Self.graph(nodeCount: 6)
        let described = String(describing: MindMapShareCard(graph: graph))
        for node in graph.nodes {
            #expect(!described.contains(node.name), "the card still carries \(node.name)")
        }
        // …and not for the trivial reason that the card kept nothing at all.
        #expect(described.contains("Mark("))
    }

    // MARK: - Fixtures

    /// Built through the real builder — `EntityGraph`'s members are not
    /// constructible from here, and going through the builder means the fixture
    /// has the same shape the app actually renders.
    static func graph(nodeCount: Int) -> EntityGraph {
        // Shared entry ids so the builder emits co-occurrence edges too.
        let entryIDs = (0 ..< nodeCount).map { _ in UUID() }
        let associations = (0 ..< nodeCount).map { index in
            EntityAssociation(
                entity: JournalEntity(
                    kind: EntityKind.allCases[index % EntityKind.allCases.count],
                    name: "Fixture name \(index)"
                ),
                // Descending mention counts, so the cap has a clear tail to cut.
                entryIDs: Array(entryIDs.prefix(max(1, nodeCount - index)))
            )
        }
        return EntityGraphBuilder.build(from: associations, topN: nodeCount)
    }
}
