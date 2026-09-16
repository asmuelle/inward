import Foundation
import SafetyKit

public enum JournalQuestionOutcome: Sendable, Equatable {
    /// The gate matched on the question or the retrieved entries: static
    /// resources only, the model never invoked.
    case suppressed(resources: [SupportResource])
    /// A grounded answer whose every citation is an entry that was retrieved.
    case answered(JournalAnswer)
    /// The model read the entries and found nothing that answers the question.
    /// The surface shows the retrieved entries themselves — never a guess.
    case notInEntries
    /// No entries to ask over, the model is unavailable, or its answer could not
    /// be trusted twice running. The surface degrades to the retrieved entries.
    case unavailable
}

/// Asking the journal a question, with the same trust shape as the weekly
/// review: the deterministic crisis gate runs before any model call (invariant
/// #5) over both the question and the retrieved text; the answer is validated
/// after (invariants #1 and #7). An answer that cites nothing real, or cites an
/// entry that was not retrieved, is regenerated once and then dropped in favour
/// of the plain retrieval list — never ungrounded prose.
public struct JournalQuestionPipeline: Sendable {
    /// Tokens the retrieved summaries may occupy: the 8K window minus a generous
    /// reserve for instructions, the question, and the structured answer.
    public static let entryTokenBudget = 5000
    /// An answer longer than this is a lecture, not a reading of the entries.
    public static let maxAnswerCharacters = 600
    /// Questions longer than this are entries in disguise.
    public static let maxQuestionCharacters = 300

    private let gate: CrisisGate
    private let provider: any JournalQuestionProviding

    public init(gate: CrisisGate = CrisisGate(), provider: any JournalQuestionProviding) {
        self.gate = gate
        self.provider = provider
    }

    public func answer(for context: QuestionContext) async -> JournalQuestionOutcome {
        let question = context.question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, question.count <= Self.maxQuestionCharacters else { return .unavailable }

        // The gate sees the question first: a crisis phrased as a question must
        // surface resources even before any entry is read.
        if case let .matched(_, resources) = gate.evaluate(question) {
            return .suppressed(resources: resources)
        }
        let retrievedText = context.entries.map(\.summary).joined(separator: "\n")
        if case let .matched(_, resources) = gate.evaluate(retrievedText) {
            return .suppressed(resources: resources)
        }

        guard !context.entries.isEmpty else { return .unavailable }
        guard case .available = await provider.availability() else { return .unavailable }

        let budgeted = context.fitting(maxTokens: Self.entryTokenBudget)
        guard !budgeted.entries.isEmpty else { return .unavailable }

        // One attempt, one regeneration on failure, then the floor.
        for _ in 0 ..< 2 {
            guard let draft = try? await provider.answer(for: budgeted) else { continue }
            if draft.isUnanswered { return .notInEntries }
            guard Self.isGrounded(draft, in: budgeted) else { continue }
            return .answered(JournalAnswer(answer: draft.answer, citedEntryIds: draft.citedEntryIds))
        }
        return .unavailable
    }

    /// A draft is shown only if its prose is non-empty, short, free of regulated
    /// vocabulary, and cites only entries that were actually retrieved.
    static func isGrounded(_ draft: JournalAnswerDraft, in context: QuestionContext) -> Bool {
        let answer = draft.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty, answer.count <= maxAnswerCharacters else { return false }
        guard !draft.citedEntryIds.isEmpty,
              draft.citedEntryIds.allSatisfy(context.citableIDs.contains)
        else { return false }
        return BannedTerms.violations(in: answer).isEmpty
    }
}
