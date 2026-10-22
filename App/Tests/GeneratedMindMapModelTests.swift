import Foundation
@testable import Inward
import JournalStore
import ReflectKit
import Testing

@MainActor
@Suite("Threads map surface — window, citations, withheld synthesis")
struct GeneratedMindMapModelTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func store(with entries: [Entry]) async throws -> EncryptedFileJournalStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("threads-map-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("journal.inward")
        let store = EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
        for entry in entries {
            try await store.save(entry: entry, transcription: nil)
        }
        return store
    }

    private func entry(daysBefore: Double, _ text: String) -> Entry {
        Entry(
            createdAt: referenceDate.addingTimeInterval(-daysBefore * 86400),
            source: .text,
            transcriptRaw: text,
            textEdited: text,
            locale: "en_US"
        )
    }

    @Test("a month of related entries draws a map whose citations all resolve")
    func drawsAndResolvesCitations() async throws {
        let entries = [
            entry(daysBefore: 1, "Garden mornings felt lighter than the rest of the day."),
            entry(daysBefore: 12, "Another garden afternoon; mornings still rushed though."),
        ]
        let model = try await GeneratedMindMapModel(
            store: store(with: entries),
            provider: MockMindMapProvider(),
            referenceDate: referenceDate
        )

        await model.draw()

        guard case let .drawn(outcome) = model.state, case let .drawn(draft) = outcome else {
            Issue.record("expected a drawn map, got \(String(describing: model.state))")
            return
        }
        #expect(!draft.branches.isEmpty)
        for id in draft.allCitedEntryIds {
            #expect(model.entry(for: id) != nil, "every citation must resolve to a real entry")
        }
    }

    @Test("entries older than the window are left off the map, newest first inside it")
    func excludesEntriesOutsideWindow() async throws {
        let entries = [
            entry(daysBefore: 1, "Garden mornings."),
            entry(daysBefore: 20, "Another garden, more mornings."),
            entry(daysBefore: 45, "Old deadline pressure from two months ago."),
        ]
        let model = try await GeneratedMindMapModel(
            store: store(with: entries),
            provider: MockMindMapProvider(),
            referenceDate: referenceDate
        )

        await model.draw()

        #expect(model.entriesByID.count == 2)
        #expect(model.hasEntries)
    }

    @Test("an empty month is quiet and never calls the provider")
    func emptyMonthIsQuiet() async throws {
        let model = try await GeneratedMindMapModel(
            store: store(with: []),
            provider: MockMindMapProvider(),
            referenceDate: referenceDate
        )

        await model.draw()

        #expect(model.state == .drawn(.unavailable))
        #expect(!model.hasEntries)
    }

    @Test("without the entitlement the map degrades to deterministic themes")
    func withheldSynthesisFallsToThemes() async throws {
        let entries = [
            entry(daysBefore: 1, "Garden mornings felt lighter."),
            entry(daysBefore: 2, "Garden mornings again."),
        ]
        let model = try await GeneratedMindMapModel(
            store: store(with: entries),
            provider: MockMindMapProvider(),
            synthesisAllowed: false,
            referenceDate: referenceDate
        )

        await model.draw()

        guard case let .drawn(outcome) = model.state, case let .themesOnly(themes) = outcome else {
            Issue.record("expected themes-only, got \(String(describing: model.state))")
            return
        }
        #expect(themes.map(\.theme).contains("garden"))
    }
}
