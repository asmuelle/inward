import Foundation
@testable import ReflectKit
import SafetyKit
import Testing

// MARK: - Fixtures

private enum Retrieved {
    static let idA = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    static let idB = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
    static let idC = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!

    static func entry(_ id: UUID, _ offsetDays: Double, _ summary: String) -> ReviewableEntry {
        ReviewableEntry(id: id, createdAt: Date(timeIntervalSince1970: offsetDays * 86400), summary: summary)
    }

    static let entries = [
        entry(idA, 1, "Garden mornings felt lighter than the rest of the day."),
        entry(idB, 2, "Another garden afternoon; mornings still rushed though."),
        entry(idC, 3, "Deadline pressure stacked up across the whole week."),
    ]

    static let context = QuestionContext(question: "When did the garden feel good?", entries: entries)

    static let crisisEntries = QuestionContext(
        question: "When did the garden feel good?",
        entries: [
            entry(idA, 1, "Garden mornings felt lighter."),
            entry(idB, 2, "Some days I think about how to end my life."),
        ]
    )

    static let crisisQuestion = QuestionContext(
        question: "Why do I keep thinking about how to end my life?",
        entries: entries
    )
}

/// Counts calls and replays a scripted list of results so regeneration is observable.
private actor ScriptedProvider: JournalQuestionProviding {
    private(set) var invocations = 0
    private(set) var lastContext: QuestionContext?
    private let results: [Result<JournalAnswerDraft, ReflectionError>]
    private let availabilityValue: ReflectionAvailability

    init(_ results: [Result<JournalAnswerDraft, ReflectionError>], availability: ReflectionAvailability = .available) {
        self.results = results
        availabilityValue = availability
    }

    nonisolated func availability() async -> ReflectionAvailability {
        availabilityValue
    }

    func answer(for context: QuestionContext) async throws -> JournalAnswerDraft {
        defer { invocations += 1 }
        lastContext = context
        switch results[min(invocations, results.count - 1)] {
        case let .success(draft): return draft
        case let .failure(error): throw error
        }
    }
}

private func grounded() -> JournalAnswerDraft {
    JournalAnswerDraft(answer: "The garden came up in the mornings.", citedEntryIds: [Retrieved.idA, Retrieved.idB])
}

private func fabricated() -> JournalAnswerDraft {
    JournalAnswerDraft(answer: "A claim about an entry that was not retrieved.", citedEntryIds: [UUID()])
}

private func unanswered() -> JournalAnswerDraft {
    JournalAnswerDraft(answer: "", citedEntryIds: [], isUnanswered: true)
}

// MARK: - Tests

@Suite("JournalQuestionPipeline — gate before model, citations verified after")
struct JournalQuestionPipelineTests {
    @Test("crisis content in the retrieved entries suppresses the model")
    func crisisInEntriesSuppressesModel() async {
        let provider = ScriptedProvider([.success(grounded())])
        let pipeline = JournalQuestionPipeline(provider: provider)

        let outcome = await pipeline.answer(for: Retrieved.crisisEntries)

        guard case let .suppressed(resources) = outcome else {
            Issue.record("expected suppression, got \(outcome)")
            return
        }
        #expect(!resources.isEmpty)
        #expect(await provider.invocations == 0)
    }

    @Test("a crisis phrased as the question itself suppresses the model before any entry is read")
    func crisisInQuestionSuppressesModel() async {
        let provider = ScriptedProvider([.success(grounded())])
        let pipeline = JournalQuestionPipeline(provider: provider)

        let outcome = await pipeline.answer(for: Retrieved.crisisQuestion)

        #expect(outcome.isSuppressed)
        #expect(await provider.invocations == 0)
    }

    @Test("a grounded answer is returned with its citations intact")
    func groundedAnswerPassesThrough() async {
        let pipeline = JournalQuestionPipeline(provider: ScriptedProvider([.success(grounded())]))

        let outcome = await pipeline.answer(for: Retrieved.context)

        #expect(outcome == .answered(JournalAnswer(
            answer: "The garden came up in the mornings.",
            citedEntryIds: [Retrieved.idA, Retrieved.idB]
        )))
    }

    @Test("a fabricated citation triggers one regeneration, then the grounded retry is shown")
    func fabricatedCitationRegeneratesOnce() async {
        let provider = ScriptedProvider([.success(fabricated()), .success(grounded())])
        let pipeline = JournalQuestionPipeline(provider: provider)

        let outcome = await pipeline.answer(for: Retrieved.context)

        guard case .answered = outcome else {
            Issue.record("expected an answer after regeneration, got \(outcome)")
            return
        }
        #expect(await provider.invocations == 2)
    }

    @Test("two ungrounded answers degrade to unavailable — never fabricated prose")
    func twoFailuresFallBack() async {
        let provider = ScriptedProvider([.success(fabricated()), .success(fabricated())])
        let pipeline = JournalQuestionPipeline(provider: provider)

        let outcome = await pipeline.answer(for: Retrieved.context)

        #expect(outcome == .unavailable)
        #expect(await provider.invocations == 2)
    }

    @Test("the model's own 'not in the entries' signal becomes notInEntries without a retry")
    func unansweredIsHonoured() async {
        let provider = ScriptedProvider([.success(unanswered())])
        let pipeline = JournalQuestionPipeline(provider: provider)

        let outcome = await pipeline.answer(for: Retrieved.context)

        #expect(outcome == .notInEntries)
        #expect(await provider.invocations == 1)
    }

    @Test("an answer containing regulated vocabulary is rejected")
    func bannedTermsRejected() async {
        let tainted = JournalAnswerDraft(
            answer: "This looks like a cognitive distortion in your entries.",
            citedEntryIds: [Retrieved.idA]
        )
        let pipeline = JournalQuestionPipeline(provider: ScriptedProvider([.success(tainted), .success(tainted)]))

        let outcome = await pipeline.answer(for: Retrieved.context)

        #expect(outcome == .unavailable)
    }

    @Test("an over-long answer is rejected as ungrounded")
    func overlongAnswerRejected() async {
        let lecture = JournalAnswerDraft(
            answer: String(repeating: "garden ", count: 120),
            citedEntryIds: [Retrieved.idA]
        )
        let pipeline = JournalQuestionPipeline(provider: ScriptedProvider([.success(lecture), .success(lecture)]))

        #expect(await pipeline.answer(for: Retrieved.context) == .unavailable)
    }

    @Test("an unavailable model yields unavailable without invoking the provider")
    func unavailableModel() async {
        let provider = ScriptedProvider([.success(grounded())], availability: .unavailable(reason: "no model"))
        let pipeline = JournalQuestionPipeline(provider: provider)

        #expect(await pipeline.answer(for: Retrieved.context) == .unavailable)
        #expect(await provider.invocations == 0)
    }

    @Test("no retrieved entries means nothing to ask over")
    func emptyRetrieval() async {
        let provider = ScriptedProvider([.success(grounded())])
        let pipeline = JournalQuestionPipeline(provider: provider)

        let outcome = await pipeline.answer(for: QuestionContext(question: "What did I write?", entries: []))

        #expect(outcome == .unavailable)
        #expect(await provider.invocations == 0)
    }

    @Test("an empty or over-long question is refused before the model")
    func degenerateQuestions() async {
        let provider = ScriptedProvider([.success(grounded())])
        let pipeline = JournalQuestionPipeline(provider: provider)

        let blank = await pipeline.answer(for: QuestionContext(question: "   ", entries: Retrieved.entries))
        let essay = await pipeline.answer(for: QuestionContext(
            question: String(repeating: "why ", count: 200),
            entries: Retrieved.entries
        ))

        #expect(blank == .unavailable)
        #expect(essay == .unavailable)
        #expect(await provider.invocations == 0)
    }

    @Test("retrieved entries are trimmed to the token budget before reaching the model")
    func budgetTrimsEntries() async {
        let long = String(repeating: "word ", count: JournalQuestionPipeline.entryTokenBudget)
        let oversized = QuestionContext(
            question: "What about the garden?",
            entries: [
                Retrieved.entry(Retrieved.idA, 1, "Garden mornings felt lighter."),
                Retrieved.entry(Retrieved.idB, 2, long),
                Retrieved.entry(Retrieved.idC, 3, "Garden again."),
            ]
        )
        let provider = ScriptedProvider([.success(JournalAnswerDraft(answer: "Garden.", citedEntryIds: [Retrieved.idA]))])
        let pipeline = JournalQuestionPipeline(provider: provider)

        _ = await pipeline.answer(for: oversized)

        let seen = await provider.lastContext?.entries.map(\.id)
        #expect(seen == [Retrieved.idA])
        let seenTokens = await provider.lastContext?.entries.map { TokenBudgeter.estimateTokens($0.summary) }.reduce(0, +)
        #expect((seenTokens ?? .max) <= JournalQuestionPipeline.entryTokenBudget)
    }

    @Test("a citation to an entry that was trimmed by the budget is not citable")
    func trimmedEntriesAreNotCitable() async {
        let long = String(repeating: "word ", count: JournalQuestionPipeline.entryTokenBudget)
        let oversized = QuestionContext(
            question: "What about the garden?",
            entries: [
                Retrieved.entry(Retrieved.idA, 1, "Garden mornings felt lighter."),
                Retrieved.entry(Retrieved.idB, 2, long),
            ]
        )
        let citesTrimmed = JournalAnswerDraft(answer: "Garden.", citedEntryIds: [Retrieved.idB])
        let pipeline = JournalQuestionPipeline(provider: ScriptedProvider([.success(citesTrimmed), .success(citesTrimmed)]))

        #expect(await pipeline.answer(for: oversized) == .unavailable)
    }
}

@Suite("QuestionContext.fitting — the retrieval order decides what survives the window")
struct QuestionContextFittingTests {
    @Test("keeps leading entries in order until the budget is spent")
    func keepsLeadingEntries() {
        let context = QuestionContext(question: "q", entries: [
            Retrieved.entry(Retrieved.idA, 1, String(repeating: "a", count: 40)), // 10 tokens
            Retrieved.entry(Retrieved.idB, 2, String(repeating: "b", count: 40)), // 10 tokens
            Retrieved.entry(Retrieved.idC, 3, String(repeating: "c", count: 4)), // 1 token
        ])

        let fitted = context.fitting(maxTokens: 15)

        #expect(fitted.entries.map(\.id) == [Retrieved.idA])
        #expect(fitted.question == "q")
    }

    @Test("everything fits when the budget is generous")
    func generousBudgetKeepsAll() {
        let fitted = Retrieved.context.fitting(maxTokens: 10000)
        #expect(fitted == Retrieved.context)
    }
}

private extension JournalQuestionOutcome {
    var isSuppressed: Bool {
        if case .suppressed = self { return true }
        return false
    }
}
