import Foundation

/// Deterministic map provider for tests and previews. Each recurring word of
/// the month becomes a branch citing exactly the entries it came from, with one
/// leaf per cited entry made of that entry's opening words — so the map is
/// grounded by construction. When nothing recurs, each entry becomes its own
/// branch, so a month with entries always draws something. No model, no
/// randomness: same month in, same map out.
public struct MockMindMapProvider: MindMapProviding {
    static let leafWordCount = 4
    static let maxEntryBranches = MindMapPipeline.maxBranches

    public init() {}

    public func availability() async -> ReflectionAvailability {
        .available
    }

    public func map(for context: MindMapContext) async throws -> MindMapDraft {
        let byID = Dictionary(context.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let themes = MindMapPipeline.recurringThemes(in: context)
        let center = context.entries.count == 1 ? "one entry" : "\(context.entries.count) entries"

        if !themes.isEmpty {
            let branches = themes.map { theme in
                MindMapBranch(
                    label: theme.theme,
                    citedEntryIds: theme.entryIds,
                    leaves: theme.entryIds.prefix(MindMapPipeline.maxLeavesPerBranch).compactMap { id in
                        byID[id].map { MindMapLeaf(label: Self.opening(of: $0.summary), citedEntryIds: [id]) }
                    }
                )
            }
            return MindMapDraft(center: center, branches: branches)
        }

        let branches = context.entries.prefix(Self.maxEntryBranches).map { entry in
            MindMapBranch(
                label: Self.opening(of: entry.summary),
                citedEntryIds: [entry.id],
                leaves: [MindMapLeaf(label: Self.opening(of: entry.summary), citedEntryIds: [entry.id])]
            )
        }
        return MindMapDraft(center: center, branches: branches)
    }

    /// The first few words of a summary, lowercased and stripped of punctuation.
    static func opening(of summary: String) -> String {
        summary.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .prefix(leafWordCount)
            .joined(separator: " ")
    }
}
