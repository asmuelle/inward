import Foundation

/// The stretch of entries a drawn map may read and cite — the last month, as
/// the app assembles it, newest first so the token budget keeps the recent
/// ones. Nothing outside `entries` is citable, which is what makes every node
/// on the map verifiable rather than a guess.
public struct MindMapContext: Sendable, Equatable {
    public let entries: [ReviewableEntry]

    public init(entries: [ReviewableEntry]) {
        self.entries = entries
    }

    /// The set of ids a grounded node is allowed to reference.
    var citableIDs: Set<UUID> {
        Set(entries.map(\.id))
    }

    /// The leading entries whose summaries fit within `maxTokens` in order —
    /// the on-device window is small, so the caller's ordering decides what
    /// survives, never the model.
    public func fitting(maxTokens: Int) -> MindMapContext {
        var kept: [ReviewableEntry] = []
        var used = 0
        for entry in entries {
            let cost = TokenBudgeter.estimateTokens(entry.summary)
            guard used + cost <= maxTokens else { break }
            used += cost
            kept.append(entry)
        }
        return MindMapContext(entries: kept)
    }
}

/// One short note hanging off a branch, in the writer's own words, pinned to
/// the entries it came from.
public struct MindMapLeaf: Sendable, Equatable, Codable {
    public let label: String
    public let citedEntryIds: [UUID]

    public init(label: String, citedEntryIds: [UUID]) {
        self.label = label
        self.citedEntryIds = citedEntryIds
    }
}

/// One thread running through the month: a short label, the entries it runs
/// through, and up to a few leaves that say what the thread looked like.
public struct MindMapBranch: Sendable, Equatable, Codable {
    public let label: String
    public let citedEntryIds: [UUID]
    public let leaves: [MindMapLeaf]

    public init(label: String, citedEntryIds: [UUID], leaves: [MindMapLeaf]) {
        self.label = label
        self.citedEntryIds = citedEntryIds
        self.leaves = leaves
    }
}

/// The drawn map: a center phrase naming the month, and its branches. Raw
/// model output until `MindMapPipeline` has verified every citation; after
/// that, the trust artifact the UI renders as tappable nodes.
public struct MindMapDraft: Sendable, Equatable, Codable {
    public let center: String
    public let branches: [MindMapBranch]

    public init(center: String, branches: [MindMapBranch]) {
        self.center = center
        self.branches = branches
    }

    /// Every entry the map points back to, branch by branch, each once.
    public var allCitedEntryIds: [UUID] {
        var seen = Set<UUID>()
        let cited = branches.flatMap { $0.citedEntryIds + $0.leaves.flatMap(\.citedEntryIds) }
        return cited.filter { seen.insert($0).inserted }
    }
}

/// Boundary for drawing a map over a month of entries. The shipped
/// implementation wraps Apple's on-device FoundationModels; tests use the
/// deterministic mock. No cloud implementation may ever exist (invariant #3).
public protocol MindMapProviding: Sendable {
    func availability() async -> ReflectionAvailability
    func map(for context: MindMapContext) async throws -> MindMapDraft
}
