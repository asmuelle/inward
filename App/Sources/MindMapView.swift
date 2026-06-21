import DesignSystem
import Foundation
import JournalStore
import RecallKit
import SwiftUI

/// Loads the entity graph and exposes the kind filter + node selection. Read-only.
@MainActor
@Observable
final class MindMapModel {
    private(set) var graph: EntityGraph = .empty
    var activeKinds: Set<EntityKind> = Set(EntityKind.allCases)
    private(set) var selectedEntries: [Entry] = []

    private let store: any JournalStoring

    init(store: any JournalStoring) {
        self.store = store
    }

    func load() async {
        let associations = await (try? store.entityAssociations()) ?? []
        graph = EntityGraphBuilder.build(from: associations)
    }

    var visibleNodes: [EntityGraph.Node] {
        graph.nodes.filter { activeKinds.contains($0.kind) }
    }

    var visibleEdges: [EntityGraph.Edge] {
        let ids = Set(visibleNodes.map(\.id))
        return graph.edges.filter { ids.contains($0.a) && ids.contains($0.b) }
    }

    func toggle(_ kind: EntityKind) {
        if activeKinds.contains(kind) { activeKinds.remove(kind) } else { activeKinds.insert(kind) }
    }

    func loadEntries(for node: EntityGraph.Node) async {
        var entries: [Entry] = []
        for id in node.entryIDs {
            if let entry = try? await store.entry(id: id) { entries.append(entry) }
        }
        selectedEntries = entries.sorted { $0.createdAt > $1.createdAt }
    }
}

/// The mind map: extracted people, places, objects, and topics laid out in calm
/// radial clusters by kind, sized by how often they recur. Tap a node to see the
/// entries it came from — it always points back at the user's own words.
struct MindMapView: View {
    @State private var model: MindMapModel
    @State private var presentedNode: EntityGraph.Node?
    private let store: any JournalStoring

    init(store: any JournalStoring) {
        self.store = store
        _model = State(initialValue: MindMapModel(store: store))
    }

    var body: some View {
        VStack(spacing: Lamplight.Spacing.element) {
            kindFilterBar
            if model.graph.isEmpty {
                emptyState
            } else {
                GeometryReader { proxy in
                    graphArea(in: proxy.size)
                }
            }
        }
        .padding(.top, Lamplight.Spacing.element)
        .background(Color.inwardPaper.ignoresSafeArea())
        .navigationTitle(Copy.mindMapTitle)
        .inwardInlineTitle()
        .task { await model.load() }
        .sheet(item: $presentedNode) { node in
            NodeEntriesSheet(node: node, model: model, store: store)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(Copy.mindMapEmpty)
                .font(.lamplight(.entryProse))
                .foregroundStyle(Color.inwardSage)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Lamplight.Spacing.stage)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var kindFilterBar: some View {
        HStack(spacing: Lamplight.Spacing.tight) {
            ForEach(EntityKind.allCases, id: \.self) { kind in
                let isOn = model.activeKinds.contains(kind)
                Button { model.toggle(kind) } label: {
                    Text(Self.label(kind))
                        .font(.lamplight(.caption))
                        .foregroundStyle(isOn ? Color.inwardPaper : Color.inwardInk)
                        .padding(.horizontal, Lamplight.Spacing.element)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(isOn ? Self.color(kind) : Color.inwardSage.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Lamplight.Spacing.block)
    }

    private func graphArea(in size: CGSize) -> some View {
        let positions = Self.positions(for: model.visibleNodes, in: size)
        return ZStack {
            Canvas { context, _ in
                for edge in model.visibleEdges {
                    guard let start = positions[edge.a], let end = positions[edge.b] else { continue }
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(
                        path,
                        with: .color(Color.inwardSage.opacity(0.2 + min(0.4, Double(edge.weight) * 0.12))),
                        lineWidth: 1 + min(3, CGFloat(edge.weight))
                    )
                }
            }
            ForEach(model.visibleNodes) { node in
                nodeView(node)
                    .position(positions[node.id] ?? CGPoint(x: size.width / 2, y: size.height / 2))
            }
        }
    }

    private func nodeView(_ node: EntityGraph.Node) -> some View {
        let diameter = 30 + min(34, CGFloat(node.mentionCount) * 7)
        return Button {
            presentedNode = node
            Task { await model.loadEntries(for: node) }
        } label: {
            VStack(spacing: 2) {
                Circle()
                    .fill(Self.color(node.kind).opacity(0.85))
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Text("\(node.mentionCount)")
                            .font(.lamplight(.caption))
                            .foregroundStyle(Color.inwardPaper)
                    )
                Text(node.name)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardInk)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Kind presentation

    static func color(_ kind: EntityKind) -> Color {
        switch kind {
        case .person: .inwardClay
        case .place: .inwardSage
        case .topic: .inwardShadowTint
        case .object: .inwardInk
        }
    }

    static func label(_ kind: EntityKind) -> String {
        switch kind {
        case .person: "People"
        case .place: "Places"
        case .object: "Things"
        case .topic: "Topics"
        }
    }

    // MARK: - Layout

    /// Static radial clusters — one angular wedge per present kind, nodes arranged
    /// in a ring within each. Deterministic and motion-free (Reduce-Motion safe).
    static func positions(for nodes: [EntityGraph.Node], in size: CGSize) -> [UUID: CGPoint] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let kinds = EntityKind.allCases.filter { kind in nodes.contains { $0.kind == kind } }
        guard !kinds.isEmpty else { return [:] }

        let shortSide = min(size.width, size.height)
        let clusterRadius = shortSide * 0.30
        let ringRadius = shortSide * 0.16
        var result: [UUID: CGPoint] = [:]

        for (kindIndex, kind) in kinds.enumerated() {
            let clusterCenter: CGPoint
            if kinds.count == 1 {
                clusterCenter = center
            } else {
                let angle = 2 * Double.pi * Double(kindIndex) / Double(kinds.count) - .pi / 2
                clusterCenter = CGPoint(
                    x: center.x + clusterRadius * cos(angle),
                    y: center.y + clusterRadius * sin(angle)
                )
            }
            let kindNodes = nodes.filter { $0.kind == kind }
            for (nodeIndex, node) in kindNodes.enumerated() {
                if kindNodes.count == 1 {
                    result[node.id] = clusterCenter
                } else {
                    let angle = 2 * Double.pi * Double(nodeIndex) / Double(kindNodes.count)
                    result[node.id] = CGPoint(
                        x: clusterCenter.x + ringRadius * cos(angle),
                        y: clusterCenter.y + ringRadius * sin(angle)
                    )
                }
            }
        }
        return result
    }
}

/// The entries one node was drawn from — the mind map's link back to real words.
private struct NodeEntriesSheet: View {
    let node: EntityGraph.Node
    let model: MindMapModel
    let store: any JournalStoring

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Lamplight.Spacing.block) {
                    ForEach(model.selectedEntries) { entry in
                        NavigationLink(value: entry) {
                            TimelineRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Lamplight.Spacing.block)
            }
            .background(Color.inwardPaper.ignoresSafeArea())
            .navigationTitle(node.name)
            .inwardInlineTitle()
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry, store: store)
            }
        }
    }
}
