import Foundation

/// A question the writer asks of their own entries, plus the only entries the
/// answer may draw on. Retrieval happens before this is built (the app's
/// RecallModel picks the candidates); nothing outside `entries` is citable, which
/// is what makes an answer verifiable rather than a guess.
public struct QuestionContext: Sendable, Equatable {
    public let question: String
    public let entries: [ReviewableEntry]

    public init(question: String, entries: [ReviewableEntry]) {
        self.question = question
        self.entries = entries
    }

    /// The set of ids a grounded answer is allowed to reference.
    var citableIDs: Set<UUID> {
        Set(entries.map(\.id))
    }

    /// The same question over the leading entries whose summaries fit within
    /// `maxTokens` in order — the on-device window is small, so the retrieval
    /// ranking decides what survives, never the model.
    public func fitting(maxTokens: Int) -> QuestionContext {
        var kept: [ReviewableEntry] = []
        var used = 0
        for entry in entries {
            let cost = TokenBudgeter.estimateTokens(entry.summary)
            guard used + cost <= maxTokens else { break }
            used += cost
            kept.append(entry)
        }
        return QuestionContext(question: question, entries: kept)
    }
}

/// Raw model output before validation. `isUnanswered` is the model's own
/// "your entries don't say" signal; the pipeline turns it into a quiet
/// not-found state rather than letting prose stand in for an answer.
public struct JournalAnswerDraft: Sendable, Equatable, Codable {
    public let answer: String
    public let citedEntryIds: [UUID]
    public let isUnanswered: Bool

    public init(answer: String, citedEntryIds: [UUID], isUnanswered: Bool = false) {
        self.answer = answer
        self.citedEntryIds = citedEntryIds
        self.isUnanswered = isUnanswered
    }
}

/// A verified answer: short second-person prose pinned to at least one real
/// entry. `citedEntryIds` is the trust artifact the UI renders as links back to
/// the writer's own words.
public struct JournalAnswer: Sendable, Equatable, Codable {
    public let answer: String
    public let citedEntryIds: [UUID]

    public init(answer: String, citedEntryIds: [UUID]) {
        self.answer = answer
        self.citedEntryIds = citedEntryIds
    }
}

/// Boundary for answering a question over retrieved entries. The shipped
/// implementation wraps Apple's on-device FoundationModels; tests use the
/// deterministic mock. No cloud implementation may ever exist (invariant #3).
public protocol JournalQuestionProviding: Sendable {
    func availability() async -> ReflectionAvailability
    func answer(for context: QuestionContext) async throws -> JournalAnswerDraft
}
