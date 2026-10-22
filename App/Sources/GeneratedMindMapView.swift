import DesignSystem
import JournalStore
import ReflectKit
import SafetyKit
import SwiftUI

/// The Threads map: a month of entries drawn as one tree by the on-device
/// model, every node tappable back to the entries it came from. The crisis
/// state shows only static resources — never model text. Model-optional: when
/// nothing can be drawn, the recurring words still form a flat map.
struct GeneratedMindMapView: View {
    @State private var model: GeneratedMindMapModel
    @State private var mode: MindMapMode = .map
    @State private var presentedNode: ThreadNode?
    private let store: any JournalStoring

    init(store: any JournalStoring, provider: any MindMapProviding, synthesisAllowed: Bool) {
        self.init(
            model: GeneratedMindMapModel(store: store, provider: provider, synthesisAllowed: synthesisAllowed),
            store: store
        )
    }

    /// For previews and the screenshot pass, which draw the model first.
    init(model: GeneratedMindMapModel, store: any JournalStoring) {
        self.store = store
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: Lamplight.Spacing.element) {
            switch model.state {
            case .idle:
                invitation
            case .drawing:
                drawing
            case let .drawn(outcome):
                drawn(outcome)
            }
        }
        .sheet(item: $presentedNode) { node in
            CitedEntriesSheet(title: node.label, entries: model.entries(for: node.citedEntryIds), store: store)
        }
    }

    // MARK: - States

    private var invitation: some View {
        VStack(spacing: Lamplight.Spacing.block) {
            Spacer()
            Text(Copy.mindMapThreadsIntro)
                .font(.lamplight(.entryProse))
                .foregroundStyle(Color.inwardSage)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Lamplight.Spacing.stage)
            drawButton(Copy.mindMapThreadsDraw)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var drawing: some View {
        VStack(spacing: Lamplight.Spacing.element) {
            Spacer()
            ProgressView().tint(.inwardClay)
            Text(Copy.mindMapThreadsDrawing)
                .font(.lamplight(.caption))
                .foregroundStyle(Color.inwardSage)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private func drawn(_ outcome: MindMapOutcome) -> some View {
        switch outcome {
        case let .drawn(draft):
            tree(ThreadTree.from(draft), note: nil)
        case let .themesOnly(themes):
            tree(ThreadTree.from(themes), note: Copy.mindMapThreadsThemesNote)
        case let .suppressed(resources):
            ScrollView {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
                    SupportResourcesBlock(resources: resources)
                }
                .padding(Lamplight.Spacing.block)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .unavailable:
            VStack(spacing: Lamplight.Spacing.block) {
                Spacer()
                Text(model.hasEntries ? Copy.mindMapThreadsUnavailable : Copy.mindMapThreadsEmpty)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardSage)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Lamplight.Spacing.stage)
                if model.hasEntries {
                    drawButton(Copy.mindMapThreadsRedraw)
                }
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private func tree(_ tree: ThreadTree, note: String?) -> some View {
        if let note {
            Text(note)
                .font(.lamplight(.caption))
                .foregroundStyle(Color.inwardSage)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Lamplight.Spacing.block)
        }
        Picker(Copy.mindMapSourceThreads, selection: $mode) {
            Text(Copy.mindMapModeMap).tag(MindMapMode.map)
            Text(Copy.mindMapModeList).tag(MindMapMode.list)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, Lamplight.Spacing.block)
        switch mode {
        case .map:
            ThreadTreeCanvas(tree: tree) { presentedNode = $0 }
        case .list:
            ThreadTreeList(tree: tree) { presentedNode = $0 }
        }
        drawButton(Copy.mindMapThreadsRedraw)
            .padding(.bottom, Lamplight.Spacing.element)
    }

    private func drawButton(_ title: String) -> some View {
        Button {
            Task { await model.draw() }
        } label: {
            HStack(spacing: Lamplight.Spacing.tight) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                Text(title)
            }
            .font(.lamplight(.chrome))
            .foregroundStyle(Color.inwardPaper)
            .padding(.horizontal, Lamplight.Spacing.block)
            .padding(.vertical, Lamplight.Spacing.element)
            .background(Capsule().fill(Color.inwardClay))
        }
        .buttonStyle(.plain)
    }
}

/// The map itself: a scrollable square large enough for six branches and
/// their leaves, opened centred on the center node. Edges are decorative —
/// each node's accessibility label and the list carry the meaning.
private struct ThreadTreeCanvas: View {
    let tree: ThreadTree
    let onOpen: (ThreadNode) -> Void

    /// Big enough that four leaves per branch keep clear of their neighbours.
    static let side: CGFloat = 760
    private static let branchLabelWidth: CGFloat = 112
    private static let leafLabelWidth: CGFloat = 96

    var body: some View {
        let layout = RadialTreeLayout.positions(leafCounts: tree.leafCounts, in: CGSize(width: Self.side, height: Self.side))
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack {
                    edges(layout)
                        .accessibilityHidden(true)
                    ForEach(Array(tree.branches.enumerated()), id: \.element.id) { index, branch in
                        ForEach(Array(tree.leaves[index].enumerated()), id: \.element.id) { leafIndex, leaf in
                            leafView(leaf)
                                .position(layout.leaves[index][leafIndex])
                        }
                        branchView(branch)
                            .position(layout.branches[index])
                    }
                    centerView(tree.center)
                        .position(layout.center)
                        .id(tree.center.id)
                }
                .frame(width: Self.side, height: Self.side)
            }
            .onAppear { proxy.scrollTo(tree.center.id, anchor: .center) }
        }
    }

    private func edges(_ layout: RadialTreeLayout.Positions) -> some View {
        Canvas { context, _ in
            for (index, branch) in layout.branches.enumerated() {
                var trunk = Path()
                trunk.move(to: layout.center)
                trunk.addLine(to: branch)
                context.stroke(trunk, with: .color(Color.inwardSage.opacity(0.5)), lineWidth: 2)
                for leaf in layout.leaves[index] {
                    var twig = Path()
                    twig.move(to: branch)
                    twig.addLine(to: leaf)
                    context.stroke(twig, with: .color(Color.inwardSage.opacity(0.3)), lineWidth: 1)
                }
            }
        }
    }

    private func centerView(_ node: ThreadNode) -> some View {
        Button { onOpen(node) } label: {
            Text(node.label)
                .font(.lamplight(.chrome))
                .foregroundStyle(Color.inwardPaper)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, Lamplight.Spacing.block)
                .padding(.vertical, Lamplight.Spacing.element)
                .frame(maxWidth: Self.branchLabelWidth + Lamplight.Spacing.block)
                .background(Capsule().fill(Color.inwardClay))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.accessibilityLabel(node))
        .accessibilityHint(Copy.mindMapThreadsCenterHint)
    }

    private func branchView(_ node: ThreadNode) -> some View {
        Button { onOpen(node) } label: {
            Text(node.label)
                .font(.lamplight(.caption))
                .fontWeight(.semibold)
                .foregroundStyle(Color.inwardPaper)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, Lamplight.Spacing.element)
                .padding(.vertical, Lamplight.Spacing.tight)
                .frame(maxWidth: Self.branchLabelWidth)
                .background(Capsule().fill(Color.inwardSage))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.accessibilityLabel(node))
        .accessibilityHint(Copy.mindMapNodeHint)
    }

    private func leafView(_ node: ThreadNode) -> some View {
        Button { onOpen(node) } label: {
            Text(node.label)
                .font(.lamplight(.caption))
                .foregroundStyle(Color.inwardInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, Lamplight.Spacing.tight)
                .padding(.vertical, Lamplight.Spacing.hairline)
                .frame(maxWidth: Self.leafLabelWidth)
                .background(
                    RoundedRectangle(cornerRadius: Lamplight.Surface.cardRadius / 2, style: .continuous)
                        .fill(Color.inwardPaper)
                        .stroke(Color.inwardSage.opacity(0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.accessibilityLabel(node))
        .accessibilityHint(Copy.mindMapNodeHint)
    }

    /// "the garden, across 3 entries" — one spoken phrase per node.
    static func accessibilityLabel(_ node: ThreadNode) -> String {
        "\(node.label), \(Copy.weeklyThemeEntryCount(node.citedEntryIds.count))"
    }
}

/// The accessible, scale-friendly fallback: every branch as a section, its
/// leaves as rows, each tappable back to the entries it came from.
private struct ThreadTreeList: View {
    let tree: ThreadTree
    let onOpen: (ThreadNode) -> Void

    var body: some View {
        List {
            Section {
                row(tree.center, prominent: true)
            }
            ForEach(Array(tree.branches.enumerated()), id: \.element.id) { index, branch in
                Section {
                    row(branch, prominent: true)
                    ForEach(tree.leaves[index]) { leaf in
                        row(leaf, prominent: false)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.inwardPaper)
    }

    private func row(_ node: ThreadNode, prominent: Bool) -> some View {
        Button { onOpen(node) } label: {
            HStack {
                Text(node.label)
                    .font(.lamplight(prominent ? .chrome : .caption))
                    .foregroundStyle(Color.inwardInk)
                Spacer()
                Text(Copy.weeklyThemeEntryCount(node.citedEntryIds.count))
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ThreadTreeCanvas.accessibilityLabel(node))
    }
}

/// The entries one node was drawn from — the map's link back to real words.
private struct CitedEntriesSheet: View {
    let title: String
    let entries: [Entry]
    let store: any JournalStoring

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Lamplight.Spacing.block) {
                    ForEach(entries) { entry in
                        NavigationLink(value: entry) {
                            TimelineRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Lamplight.Spacing.block)
            }
            .background(Color.inwardPaper.ignoresSafeArea())
            .navigationTitle(title)
            .inwardInlineTitle()
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry, store: store)
            }
        }
    }
}

/// Static resources for the crisis state — never model text (invariant #5).
/// Mirrors the weekly review's support block so both surfaces read as one.
private struct SupportResourcesBlock: View {
    let resources: [SupportResource]

    var body: some View {
        VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
            Text(Copy.supportHeader)
                .font(.lamplight(.journalTitle))
                .foregroundStyle(Color.inwardInk)
            Text(Copy.supportIntro)
                .font(.lamplight(.entryProse))
                .foregroundStyle(Color.inwardInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(resources) { resource in
            PaperCard {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
                    Text(resource.name)
                        .font(.lamplight(.chrome))
                        .foregroundStyle(Color.inwardInk)
                    Text(resource.detail)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
