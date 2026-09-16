import DesignSystem
import JournalStore
import RecallKit
import SwiftUI

/// The mind map as a constellation: one circle per recurring thing, sized by how
/// often it came up, connected where they appeared together.
///
/// **Names are deliberately absent, and absent by construction.** The map on
/// screen is labelled — it is the user's own private index of people and places.
/// A picture bound for a share sheet is not: it would carry other people's names
/// out of the phone, and those people never agreed to that.
///
/// So the card does not hold nodes. `init` reduces the graph to `Mark`s and
/// `Strand`s — geometry and kind, no text — and the name has nowhere left to go.
/// That is a stronger guarantee than remembering not to draw it.
struct MindMapShareCard: View {
    /// Past this many circles the constellation turns to noise at poster size.
    nonisolated static let maxNodes = 24

    /// One circle: where, how big, what kind. Deliberately no name.
    struct Mark: Identifiable, Equatable {
        let id: UUID
        let center: CGPoint
        let diameter: CGFloat
        let kind: EntityKind
    }

    /// One connecting line between two marks.
    struct Strand: Equatable {
        let from: CGPoint
        let to: CGPoint
        let weight: Int
    }

    private let marks: [Mark]
    private let strands: [Strand]

    /// The drawing area inside the card's margins — wide, not square, so the
    /// headline and caption keep their air.
    static let field = CGSize(width: 888, height: 620)

    init(graph: EntityGraph) {
        let nodes = Self.displayedNodes(graph.nodes)
        // Same deterministic radial layout as the on-screen map, so the picture
        // is recognisably the map the user has been looking at.
        let positions = MindMapView.positions(for: nodes, in: Self.field)
        let fallback = CGPoint(x: Self.field.width / 2, y: Self.field.height / 2)

        marks = nodes.map { node in
            Mark(
                id: node.id,
                center: positions[node.id] ?? fallback,
                diameter: Self.diameter(for: node),
                kind: node.kind
            )
        }
        strands = Self.keptEdges(graph.edges, among: nodes).compactMap { edge in
            guard let from = positions[edge.a], let to = positions[edge.b] else { return nil }
            return Strand(from: from, to: to, weight: edge.weight)
        }
    }

    /// The circles that make the card: the most-mentioned first, capped. Pure,
    /// so the cap is testable without rasterizing anything (`nonisolated`
    /// because `View` conformance would otherwise pin it to the main actor).
    nonisolated static func displayedNodes(_ nodes: [EntityGraph.Node]) -> [EntityGraph.Node] {
        Array(
            nodes
                .sorted { ($0.mentionCount, $0.name) > ($1.mentionCount, $1.name) }
                .prefix(maxNodes)
        )
    }

    /// Drawing every co-occurrence turns the constellation into a hairball at
    /// poster size, so only the strongest connections are kept.
    nonisolated static let maxStrands = 28

    /// Only edges whose endpoints both survived the cap — a line to a circle
    /// that isn't drawn reads as a stray mark — and only the strongest of those.
    nonisolated static func keptEdges(
        _ edges: [EntityGraph.Edge],
        among nodes: [EntityGraph.Node]
    ) -> [EntityGraph.Edge] {
        let ids = Set(nodes.map(\.id))
        return Array(
            edges
                .filter { ids.contains($0.a) && ids.contains($0.b) }
                .sorted { ($0.weight, $0.id) > ($1.weight, $1.id) }
                .prefix(maxStrands)
        )
    }

    /// Poster-scale circles: the on-screen sizes are tuned for a phone and
    /// vanish at 1080px wide.
    nonisolated static func diameter(for node: EntityGraph.Node) -> CGFloat {
        28 + min(64, CGFloat(node.mentionCount) * 11)
    }

    var body: some View {
        ShareCardCanvas {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
                Text(Copy.shareMindMapHeadline)
                    .font(.shareCard(.body))
                    .foregroundStyle(Color.inwardInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                constellation
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                Text(Copy.shareMindMapCaption)
                    .font(.shareCard(.caption))
                    .foregroundStyle(Color.inwardSage)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var constellation: some View {
        ZStack {
            Canvas { context, _ in
                for strand in strands {
                    var path = Path()
                    path.move(to: strand.from)
                    path.addLine(to: strand.to)
                    context.stroke(
                        path,
                        with: .color(Color.inwardSage.opacity(0.22 + min(0.38, Double(strand.weight) * 0.1))),
                        lineWidth: 2 + min(7, CGFloat(strand.weight) * 1.5)
                    )
                }
            }
            ForEach(marks) { mark in
                Circle()
                    .fill(MindMapView.color(mark.kind).opacity(0.82))
                    .frame(width: mark.diameter, height: mark.diameter)
                    .position(mark.center)
            }
        }
        .frame(width: Self.field.width, height: Self.field.height)
    }
}
