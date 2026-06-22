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
    var searchText: String = ""
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

    /// Kind-filtered nodes narrowed by the search query (case- and
    /// diacritic-insensitive). Drives both the map and the accessible list.
    var matchedNodes: [EntityGraph.Node] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return visibleNodes }
        return visibleNodes.filter {
            $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var visibleEdges: [EntityGraph.Edge] {
        let ids = Set(matchedNodes.map(\.id))
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
enum MindMapMode: Hashable { case map, list }

struct MindMapView: View {
    @State private var model: MindMapModel
    @State private var presentedNode: EntityGraph.Node?
    @State private var mode: MindMapMode = .map
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
                searchField
                modePicker
                switch mode {
                case .map:
                    GeometryReader { proxy in
                        graphArea(in: proxy.size)
                    }
                case .list:
                    nodeList
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

    private var searchField: some View {
        HStack(spacing: Lamplight.Spacing.tight) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inwardSage)
            TextField(
                Copy.mindMapSearchPrompt,
                text: Binding(get: { model.searchText }, set: { model.searchText = $0 })
            )
            .font(.lamplight(.caption))
            .foregroundStyle(Color.inwardInk)
            .autocorrectionDisabled()
            .textFieldStyle(.plain)
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif
        }
        .padding(.horizontal, Lamplight.Spacing.element)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.inwardSage.opacity(0.12)))
        .padding(.horizontal, Lamplight.Spacing.block)
    }

    private var modePicker: some View {
        Picker(Copy.mindMapTitle, selection: $mode) {
            Text(Copy.mindMapModeMap).tag(MindMapMode.map)
            Text(Copy.mindMapModeList).tag(MindMapMode.list)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, Lamplight.Spacing.block)
    }

    /// The accessible, scale-friendly fallback: every matched node as a plain row,
    /// grouped by kind and ordered by how often it recurs. No spatial layout to get
    /// lost in, and it reads cleanly under VoiceOver.
    private var nodeList: some View {
        List {
            ForEach(EntityKind.allCases, id: \.self) { kind in
                let nodes = model.matchedNodes
                    .filter { $0.kind == kind }
                    .sorted { $0.mentionCount > $1.mentionCount }
                if !nodes.isEmpty {
                    Section(Self.label(kind)) {
                        ForEach(nodes) { node in
                            Button {
                                presentedNode = node
                                Task { await model.loadEntries(for: node) }
                            } label: {
                                HStack {
                                    Text(node.name)
                                        .font(.lamplight(.chrome))
                                        .foregroundStyle(Color.inwardInk)
                                    Spacer()
                                    Text("\(node.mentionCount)")
                                        .font(.lamplight(.caption))
                                        .foregroundStyle(Color.inwardSage)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Self.nodeAccessibilityLabel(node))
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.inwardPaper)
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
        let positions = Self.positions(for: model.matchedNodes, in: size)
        return ZStack {
            // The edges are decorative; their meaning is carried by each node's
            // accessibility label and the list fallback, so VoiceOver skips them.
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
            .accessibilityHidden(true)
            ForEach(model.matchedNodes) { node in
                nodeView(node)
                    .position(positions[node.id] ?? CGPoint(x: size.width / 2, y: size.height / 2))
            }
        }
    }

    /// Cap on a node label's width so long extracted names truncate instead of
    /// colliding with their neighbours in the radial layout.
    private static let nodeLabelMaxWidth: CGFloat = 88

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
                    .truncationMode(.tail)
                    .frame(maxWidth: Self.nodeLabelMaxWidth)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.nodeAccessibilityLabel(node))
        .accessibilityHint(Copy.mindMapNodeHint)
    }

    /// "Sarah, People, 5 mentions" — one spoken phrase per node, since the visual
    /// circle/count/name split reads as disconnected fragments otherwise.
    static func nodeAccessibilityLabel(_ node: EntityGraph.Node) -> String {
        "\(node.name), \(label(node.kind)), \(Copy.mindMapMentions(node.mentionCount))"
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
        case .person: Copy.mindMapPeople
        case .place: Copy.mindMapPlaces
        case .object: Copy.mindMapThings
        case .topic: Copy.mindMapTopics
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
