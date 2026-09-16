import Foundation
@testable import Inward
import JournalStore
import ReflectKit
import Testing

@MainActor
@Suite("Ask-the-entries surface — retrieval to verified answer")
struct AskJournalModelTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(daysBefore: Double, _ text: String) -> Entry {
        Entry(
            createdAt: referenceDate.addingTimeInterval(-daysBefore * 86400),
            source: .text,
            transcriptRaw: text,
            textEdited: text,
            locale: "en_US"
        )
    }

    @Test("a question over matching entries yields an answer whose citations all resolve")
    func answersAndResolvesCitations() async {
        let garden = entry(daysBefore: 1, "Garden mornings felt lighter than the rest of the day.")
        let deadline = entry(daysBefore: 2, "Deadline pressure stacked up across the whole week.")
        let model = AskJournalModel(provider: MockJournalQuestionProvider())

        await model.ask("When did the garden feel light?", candidates: [garden, deadline])

        guard case let .answered(.answered(answer)) = model.state else {
            Issue.record("expected an answer, got \(model.state)")
            return
        }
        #expect(answer.citedEntryIds == [garden.id])
        #expect(model.entry(for: garden.id) == garden)
    }

    @Test("a question nothing was written about degrades to notInEntries")
    func notInEntries() async {
        let model = AskJournalModel(provider: MockJournalQuestionProvider())

        await model.ask("What about the ocean?", candidates: [entry(daysBefore: 1, "Garden mornings.")])

        #expect(model.state == .answered(.notInEntries))
    }

    @Test("crisis content among the retrieved entries shows resources, never model text")
    func crisisSuppresses() async {
        let model = AskJournalModel(provider: MockJournalQuestionProvider())
        let candidates = [
            entry(daysBefore: 1, "Garden mornings felt lighter."),
            entry(daysBefore: 2, "Some days I think about how to end my life."),
        ]

        await model.ask("When did the garden feel light?", candidates: candidates)

        guard case let .answered(.suppressed(resources)) = model.state else {
            Issue.record("expected suppression, got \(model.state)")
            return
        }
        #expect(!resources.isEmpty)
    }

    @Test("only the top-ranked candidates are retrieved, best match first")
    func retrievalIsCapped() async {
        let many = (0 ..< 20).map { entry(daysBefore: Double($0), "Garden note number \($0).") }
        let model = AskJournalModel(provider: MockJournalQuestionProvider())

        await model.ask("How often did I mention the garden?", candidates: many)

        #expect(model.entriesByID.count == AskJournalModel.maxRetrieved)
        #expect(many.prefix(AskJournalModel.maxRetrieved).allSatisfy { model.entry(for: $0.id) != nil })
    }

    @Test("reset clears the answer and the lookup")
    func resetClears() async {
        let model = AskJournalModel(provider: MockJournalQuestionProvider())
        await model.ask("When was the garden light?", candidates: [entry(daysBefore: 1, "Garden mornings.")])

        model.reset()

        #expect(model.state == .idle)
        #expect(model.entriesByID.isEmpty)
    }
}
