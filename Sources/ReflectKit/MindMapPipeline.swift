import Foundation
import SafetyKit

public enum MindMapOutcome: Sendable, Equatable {
    /// The gate matched somewhere in the month: static resources only, the
    /// model never invoked.
    case suppressed(resources: [SupportResource])
    /// A drawn map whose every node cites at least one real entry of the month.
    case drawn(MindMapDraft)
    /// The model is unavailable, withheld, or could not be trusted twice
    /// running: the month degrades to deterministic recurring-theme counts,
    /// rendered as a flat map — never fabricated structure.
    case themesOnly([ThemeCount])
    /// Nothing to draw: no entries, or no recurring words to fall back on.
    case unavailable
}

/// Drawing a mind map of the month, with the same trust shape as the weekly
/// review: the deterministic crisis gate runs before any model call (invariant
/// #5) over every summary the model would see; the draft is validated after
/// (invariants #1 and #7). A map with an empty node, an uncited node, a
/// citation outside the month, or regulated vocabulary is regenerated once and
/// then replaced by deterministic theme counts — never ungrounded structure.
public struct MindMapPipeline: Sendable {
    /// Tokens the summaries may occupy: the window minus a generous reserve
    /// for instructions and the structured map, which is larger than an answer.
    public static let entryTokenBudget = 4000
    public static let maxBranches = 6
    public static let maxLeavesPerBranch = 4
    /// A node label longer than this is a sentence, not a map node.
    public static let maxLabelCharacters = 60

    private let gate: CrisisGate
    private let provider: any MindMapProviding

    public init(gate: CrisisGate = CrisisGate(), provider: any MindMapProviding) {
        self.gate = gate
        self.provider = provider
    }

    public func map(for context: MindMapContext) async -> MindMapOutcome {
        guard !context.entries.isEmpty else { return .unavailable }

        let monthText = context.entries.map(\.summary).joined(separator: "\n")
        if case let .matched(_, resources) = gate.evaluate(monthText) {
            return .suppressed(resources: resources)
        }

        guard case .available = await provider.availability() else { return floor(for: context) }

        let budgeted = context.fitting(maxTokens: Self.entryTokenBudget)
        guard !budgeted.entries.isEmpty else { return floor(for: context) }

        // One attempt, one regeneration on failure, then the floor.
        for _ in 0 ..< 2 {
            guard let draft = try? await provider.map(for: budgeted),
                  Self.isGrounded(draft, in: budgeted)
            else { continue }
            return .drawn(draft)
        }
        return floor(for: context)
    }

    /// Model-optional (invariant #9): the deterministic recurring themes of the
    /// month, each carrying the real entries it came from, or nothing at all.
    private func floor(for context: MindMapContext) -> MindMapOutcome {
        let themes = Self.recurringThemes(in: context)
        return themes.isEmpty ? .unavailable : .themesOnly(themes)
    }

    /// The weekly review's theme counting, over the month. Public so a surface
    /// can show the floor without going through the model at all.
    public static func recurringThemes(in context: MindMapContext) -> [ThemeCount] {
        WeeklyReviewPipeline.recurringThemes(in: WeekContext(weekStart: .distantPast, entries: context.entries))
    }

    /// A draft is drawn only if its center and every branch and leaf are
    /// non-empty, short, free of regulated vocabulary, cite at least one entry,
    /// and cite only entries that are actually in the month.
    static func isGrounded(_ draft: MindMapDraft, in context: MindMapContext) -> Bool {
        guard isCleanLabel(draft.center) else { return false }
        guard (1 ... maxBranches).contains(draft.branches.count) else { return false }
        let citable = context.citableIDs

        return draft.branches.allSatisfy { branch in
            guard isCleanLabel(branch.label), isCited(branch.citedEntryIds, within: citable) else { return false }
            guard branch.leaves.count <= maxLeavesPerBranch else { return false }
            return branch.leaves.allSatisfy { leaf in
                isCleanLabel(leaf.label) && isCited(leaf.citedEntryIds, within: citable)
            }
        }
    }

    private static func isCleanLabel(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLabelCharacters else { return false }
        return BannedTerms.violations(in: trimmed).isEmpty
    }

    private static func isCited(_ ids: [UUID], within citable: Set<UUID>) -> Bool {
        !ids.isEmpty && ids.allSatisfy(citable.contains)
    }
}
