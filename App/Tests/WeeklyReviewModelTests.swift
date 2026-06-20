import Foundation
@testable import Inward
import JournalStore
import ReflectKit
import Testing

@MainActor
@Suite("Weekly review surface — assembly and citation resolution")
struct WeeklyReviewModelTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func store(with entries: [Entry]) async throws -> EncryptedFileJournalStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("weekly-review-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("journal.inward")
        let store = EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
        for entry in entries {
            try await store.save(entry: entry, transcription: nil)
        }
        return store
    }

    private func entry(daysBefore: Double, _ text: String) -> Entry {
        Entry(
            createdAt: referenceDate.addingTimeInterval(-daysBefore * 86_400),
            source: .text,
            transcriptRaw: text,
            textEdited: text,
            locale: "en_US"
        )
    }

    @Test("a week of related entries yields a synthesized review whose citations all resolve")
    func synthesizesAndResolvesCitations() async throws {
        let entries = [
            entry(daysBefore: 1, "Garden mornings felt lighter than the rest of the day."),
            entry(daysBefore: 2, "Another garden afternoon; mornings still rushed though."),
        ]
        let model = WeeklyReviewModel(
            store: try await store(with: entries),
            provider: MockWeeklyReviewProvider(),
            referenceDate: referenceDate
        )

        await model.load()

        guard case let .synthesized(draft) = model.outcome else {
            Issue.record("expected a synthesized review, got \(String(describing: model.outcome))")
            return
        }
        #expect(!draft.observations.isEmpty)
        for observation in draft.observations {
            #expect(!observation.citedEntryIds.isEmpty)
            for id in observation.citedEntryIds {
                #expect(model.entry(for: id) != nil, "every citation must resolve to a real entry")
            }
        }
    }

    @Test("entries older than the window are excluded from the week")
    func excludesEntriesOutsideWindow() async throws {
        let entries = [
            entry(daysBefore: 1, "Garden mornings."),
            entry(daysBefore: 2, "Another garden, more mornings."),
            entry(daysBefore: 30, "Old deadline pressure from last month."),
        ]
        let model = WeeklyReviewModel(
            store: try await store(with: entries),
            provider: MockWeeklyReviewProvider(),
            referenceDate: referenceDate
        )

        await model.load()

        #expect(model.entriesByID.count == 2, "only the two in-window entries belong to this week")
    }

    @Test("an empty week is a quiet, entry-free state")
    func emptyWeekIsQuiet() async throws {
        let model = WeeklyReviewModel(
            store: try await store(with: []),
            provider: MockWeeklyReviewProvider(),
            referenceDate: referenceDate
        )

        await model.load()

        #expect(model.outcome == .unavailable)
        #expect(model.hasEntriesThisWeek == false)
    }
}
