import Foundation
import JournalStore
@testable import PrivacyKit
import Testing

private let when = Date(timeIntervalSince1970: 1_700_000_000)
private let idA = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
private let idB = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
private let idC = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!

private func entry(_ id: UUID, _ text: String) -> Entry {
    Entry(id: id, createdAt: when, source: .text, transcriptRaw: text, textEdited: text, locale: "en_US")
}

private func transcription(for id: UUID) -> Transcription {
    Transcription(entryId: id, engine: .speechTranscriber, confidence: 0.9, completedAt: when)
}

private func payload(entries: [Entry], transcriptions: [Transcription] = []) -> ExportPayload {
    ExportPayload(exportedAt: when, entries: entries, transcriptions: transcriptions)
}

@Suite("JournalImporter — additive union-by-id merge")
struct JournalImporterTests {
    @Test("an empty device takes every entry, in source order")
    func emptyDeviceTakesAll() {
        let entries = [entry(idA, "first"), entry(idB, "second"), entry(idC, "third")]

        let additions = JournalImporter.additions(from: payload(entries: entries), existingIDs: [])

        #expect(additions.map(\.entry) == entries)
    }

    @Test("entries the device already has are skipped")
    func skipsKnownIDs() {
        let entries = [entry(idA, "first"), entry(idB, "second"), entry(idC, "third")]

        let additions = JournalImporter.additions(from: payload(entries: entries), existingIDs: [idB])

        #expect(additions.map(\.entry.id) == [idA, idC])
    }

    @Test("nothing is added when the device already has every entry")
    func noOpWhenFullyPresent() {
        let entries = [entry(idA, "first"), entry(idB, "second")]

        let additions = JournalImporter.additions(from: payload(entries: entries), existingIDs: [idA, idB])

        #expect(additions.isEmpty)
    }

    @Test("each new entry keeps its transcription, matched by id")
    func pairsTranscriptionByID() {
        let entries = [entry(idA, "spoken"), entry(idB, "typed")]
        let result = JournalImporter.additions(
            from: payload(entries: entries, transcriptions: [transcription(for: idA)]),
            existingIDs: []
        )

        let byID = Dictionary(uniqueKeysWithValues: result.map { ($0.entry.id, $0.transcription) })
        #expect(byID[idA] == transcription(for: idA))
        #expect(byID[idB] == .some(nil)) // present in result, but carried no transcription
    }

    @Test("a transcription for an already-present entry is not re-added")
    func skippedEntryDropsItsTranscription() {
        let entries = [entry(idA, "old"), entry(idB, "new")]
        let result = JournalImporter.additions(
            from: payload(entries: entries, transcriptions: [transcription(for: idA), transcription(for: idB)]),
            existingIDs: [idA]
        )

        #expect(result.count == 1)
        #expect(result.first?.entry.id == idB)
        #expect(result.first?.transcription == transcription(for: idB))
    }

    @Test("a real exported archive merges additively after a round-trip")
    func mergesAfterRoundTrip() throws {
        let entries = [entry(idA, "Coffee on the balcony."), entry(idB, "Quiet end to a long day.")]
        let data = try JournalExporter.archiveData(
            entries: entries,
            transcriptions: [transcription(for: idA)],
            exportedAt: when,
            passphrase: "open sesame",
            iterations: 1000
        )
        let restored = try JournalExporter.restore(from: data, passphrase: "open sesame")

        // Device already holds the first entry; only the second should come in.
        let additions = JournalImporter.additions(from: restored, existingIDs: [idA])

        #expect(additions.map(\.entry) == [entries[1]])
        #expect(additions.first?.transcription == nil)
    }
}
