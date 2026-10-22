import DesignSystem
import Foundation
import ReflectKit

/// One node of the drawn map as the view sees it: a label and the entries it
/// points back to. The same shape serves the model's draft and the
/// deterministic themes-only floor, so the map renders one way.
struct ThreadNode: Identifiable, Equatable {
    let id: String
    let label: String
    let citedEntryIds: [UUID]
}

/// The drawn map flattened for layout: a center, its branches, and each
/// branch's leaves by index — exactly what `RadialTreeLayout` positions.
struct ThreadTree: Equatable {
    let center: ThreadNode
    let branches: [ThreadNode]
    /// `leaves[b]` are the leaves of `branches[b]`.
    let leaves: [[ThreadNode]]

    var leafCounts: [Int] {
        leaves.map(\.count)
    }

    static func from(_ draft: MindMapDraft) -> ThreadTree {
        ThreadTree(
            center: ThreadNode(id: "center", label: draft.center, citedEntryIds: draft.allCitedEntryIds),
            branches: draft.branches.enumerated().map { index, branch in
                ThreadNode(id: "b\(index)", label: branch.label, citedEntryIds: branch.citedEntryIds)
            },
            leaves: draft.branches.enumerated().map { branchIndex, branch in
                branch.leaves.enumerated().map { leafIndex, leaf in
                    ThreadNode(id: "b\(branchIndex)l\(leafIndex)", label: leaf.label, citedEntryIds: leaf.citedEntryIds)
                }
            }
        )
    }

    /// The floor: recurring words as branches around a fixed center, no leaves.
    static func from(_ themes: [ThemeCount]) -> ThreadTree {
        var seen = Set<UUID>()
        let all = themes.flatMap(\.entryIds).filter { seen.insert($0).inserted }
        return ThreadTree(
            center: ThreadNode(id: "center", label: Copy.mindMapThreadsCenterFallback, citedEntryIds: all),
            branches: themes.enumerated().map { index, theme in
                ThreadNode(id: "b\(index)", label: theme.theme, citedEntryIds: theme.entryIds)
            },
            leaves: themes.map { _ in [] }
        )
    }
}
