import Foundation
@testable import ReflectKit
import Testing

@Suite("MockJournalQuestionProvider — grounded by construction")
struct MockJournalQuestionProviderTests {
    private let idA = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let idB = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!

    private func context(_ question: String) -> QuestionContext {
        QuestionContext(question: question, entries: [
            ReviewableEntry(id: idA, createdAt: Date(timeIntervalSince1970: 0), summary: "Garden mornings felt lighter."),
            ReviewableEntry(id: idB, createdAt: Date(timeIntervalSince1970: 86400), summary: "Deadline pressure all week."),
        ])
    }

    @Test("cites exactly the entries that share a word with the question")
    func citesSharedWordEntries() async throws {
        let draft = try await MockJournalQuestionProvider().answer(for: context("When did the garden feel light?"))

        #expect(draft.citedEntryIds == [idA])
        #expect(draft.isUnanswered == false)
        #expect(draft.answer.contains("garden"))
    }

    @Test("reports unanswered when no entry shares a word")
    func unansweredWhenNothingMatches() async throws {
        let draft = try await MockJournalQuestionProvider().answer(for: context("What about the ocean?"))

        #expect(draft.isUnanswered)
        #expect(draft.citedEntryIds.isEmpty)
    }

    @Test("its output passes the pipeline's grounding check")
    func passesPipeline() async {
        let pipeline = JournalQuestionPipeline(provider: MockJournalQuestionProvider())

        let outcome = await pipeline.answer(for: context("When did the garden feel light?"))

        guard case let .answered(answer) = outcome else {
            Issue.record("expected an answer, got \(outcome)")
            return
        }
        #expect(answer.citedEntryIds == [idA])
    }
}
