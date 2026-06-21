import CryptoKit
import Foundation
import JournalStore
@testable import JournalStoreSQLCipher
import Testing

private func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("inward-sqlcipher-tests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("journal.db")
}

private func makeEntry(
    text: String = "Spoke about the move and the long silence after.",
    at date: Date = Date(timeIntervalSince1970: 1_750_000_000)
) -> Entry {
    Entry(
        createdAt: date,
        source: .voice,
        transcriptRaw: text,
        textEdited: text,
        durationSec: 42.5,
        locale: "en_US"
    )
}

@Suite("SQLCipherJournalStore — encrypted SQLite behind JournalStoring")
struct SQLCipherJournalStoreTests {
    @Test("entry and transcription round-trip through one save")
    func saveAndFetchRoundTrip() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        let transcription = Transcription(entryId: entry.id, engine: .mock, confidence: 0.91, completedAt: entry.createdAt)

        try await store.save(entry: entry, transcription: transcription)

        #expect(try await store.entry(id: entry.id) == entry)
        #expect(try await store.transcription(entryID: entry.id) == transcription)
    }

    @Test("the precomputed summary is persisted, not recomputed on read")
    func summaryPersists() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        // An explicit summary that differs from what EntrySummary.make would derive.
        let entry = Entry(
            createdAt: Date(timeIntervalSince1970: 1_750_000_000),
            source: .text,
            transcriptRaw: "raw",
            textEdited: "Some ordinary opening line here.",
            summary: "a pinned summary",
            locale: "en_US"
        )
        try await store.save(entry: entry, transcription: nil)

        let fetched = try await store.entry(id: entry.id)

        #expect(fetched?.summary == "a pinned summary")
    }

    @Test("all entries come back newest first")
    func ordersNewestFirst() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let older = makeEntry(text: "older", at: Date(timeIntervalSince1970: 1000))
        let newer = makeEntry(text: "newer", at: Date(timeIntervalSince1970: 2000))
        try await store.save(entry: older, transcription: nil)
        try await store.save(entry: newer, transcription: nil)

        let entries = try await store.allEntries()

        #expect(entries.map(\.id) == [newer.id, older.id])
    }

    @Test("editing replaces the text and leaves the raw transcript untouched")
    func updateEditedText() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry(text: "first words")
        try await store.save(entry: entry, transcription: nil)

        let updated = try await store.updateEditedText(entryID: entry.id, textEdited: "second words")

        #expect(updated.textEdited == "second words")
        #expect(updated.transcriptRaw == "first words")
        #expect(try await store.entry(id: entry.id)?.textEdited == "second words")
    }

    @Test("editing a missing entry throws entryNotFound, not a wrapped error")
    func updateMissingThrows() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let ghost = UUID()

        await #expect(throws: JournalStoreError.entryNotFound(ghost)) {
            try await store.updateEditedText(entryID: ghost, textEdited: "nope")
        }
    }

    @Test("editing advances updatedAt past createdAt and re-summarizes")
    func editAdvancesUpdatedAt() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        try await store.save(entry: entry, transcription: nil)
        #expect(entry.updatedAt == entry.createdAt)

        let updated = try await store.updateEditedText(entryID: entry.id, textEdited: "A wholly new line.")

        #expect(updated.updatedAt > entry.createdAt)
        #expect(updated.summary == "A wholly new line.")
    }

    @Test("delete removes the entry and cascades its transcription")
    func deleteCascades() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        let transcription = Transcription(entryId: entry.id, engine: .mock, confidence: 0.9, completedAt: entry.createdAt)
        try await store.save(entry: entry, transcription: transcription)

        try await store.delete(entryID: entry.id)

        #expect(try await store.entry(id: entry.id) == nil)
        #expect(try await store.transcription(entryID: entry.id) == nil, "the transcription cascades with its entry")
    }

    @Test("deleting a missing entry throws entryNotFound")
    func deleteMissingThrows() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let ghost = UUID()

        await #expect(throws: JournalStoreError.entryNotFound(ghost)) {
            try await store.delete(entryID: ghost)
        }
    }

    @Test("tags round-trip, normalized and deduped, sorted by name")
    func tagsRoundTrip() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        try await store.save(entry: entry, transcription: nil)

        try await store.setTags(["Mornings", " mornings ", "Work", ""], for: entry.id)

        #expect(try await store.tags(for: entry.id).map(\.name) == ["mornings", "work"])
    }

    @Test("allTags lists the vocabulary and entries(withTag:) filters case-insensitively")
    func allTagsAndFilter() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let newer = makeEntry(text: "a", at: Date(timeIntervalSince1970: 2000))
        let older = makeEntry(text: "b", at: Date(timeIntervalSince1970: 1000))
        try await store.save(entry: newer, transcription: nil)
        try await store.save(entry: older, transcription: nil)
        try await store.setTags(["work"], for: newer.id)
        try await store.setTags(["home"], for: older.id)

        #expect(try await store.allTags().map(\.name) == ["home", "work"])
        #expect(try await store.entries(withTag: "WORK").map(\.id) == [newer.id])
    }

    @Test("retagging prunes tags that no entry references anymore")
    func retaggingPrunesOrphans() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        try await store.save(entry: entry, transcription: nil)
        try await store.setTags(["temp"], for: entry.id)

        try await store.setTags(["keep"], for: entry.id)

        #expect(try await store.allTags().map(\.name) == ["keep"])
    }

    @Test("deleting an entry removes its tag links and prunes orphans")
    func deletePrunesTags() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        try await store.save(entry: entry, transcription: nil)
        try await store.setTags(["solo"], for: entry.id)

        try await store.delete(entryID: entry.id)

        #expect(try await store.allTags().isEmpty)
    }

    @Test("tagging a missing entry throws entryNotFound")
    func setTagsMissingThrows() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let ghost = UUID()

        await #expect(throws: JournalStoreError.entryNotFound(ghost)) {
            try await store.setTags(["x"], for: ghost)
        }
    }

    @Test("entities round-trip, dedupe by kind+name, and mark the entry processed")
    func entitiesRoundTrip() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        try await store.save(entry: entry, transcription: nil)
        #expect(try await store.entryIDsNeedingInsights(limit: 10) == [entry.id])

        try await store.setEntities([
            JournalEntity(kind: .person, name: "Sarah"),
            JournalEntity(kind: .person, name: "sarah"),
            JournalEntity(kind: .place, name: "Berlin"),
            JournalEntity(kind: .topic, name: "mornings"),
        ], for: entry.id)

        let entities = try await store.entities(for: entry.id)
        #expect(entities.count(where: { $0.kind == .person }) == 1)
        #expect(Set(entities.map(\.name)) == ["Sarah", "Berlin", "mornings"])
        #expect(try await store.entryIDsNeedingInsights(limit: 10).isEmpty, "processed entries leave the queue")
    }

    @Test("an empty extraction still marks the entry processed")
    func emptyExtractionMarksProcessed() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        try await store.save(entry: entry, transcription: nil)

        try await store.setEntities([], for: entry.id)

        #expect(try await store.entities(for: entry.id).isEmpty)
        #expect(try await store.entryIDsNeedingInsights(limit: 10).isEmpty)
    }

    @Test("re-extracting prunes orphan entities; shared ones survive until the last reference")
    func entityPruningAndSharing() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let newer = makeEntry(text: "a", at: Date(timeIntervalSince1970: 2000))
        let older = makeEntry(text: "b", at: Date(timeIntervalSince1970: 1000))
        try await store.save(entry: newer, transcription: nil)
        try await store.save(entry: older, transcription: nil)

        try await store.setEntities([JournalEntity(kind: .place, name: "Berlin")], for: newer.id)
        try await store.setEntities([JournalEntity(kind: .place, name: "berlin")], for: older.id) // reuses the row

        try await store.delete(entryID: newer.id) // older still references "Berlin"
        #expect(try await store.entities(for: older.id).map(\.name) == ["Berlin"])

        try await store.setEntities([], for: older.id) // last reference gone → pruned
        #expect(try await store.entities(for: older.id).isEmpty)
    }

    @Test("extracted topics are suggested until tagged or dismissed")
    func tagSuggestions() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        try await store.save(entry: entry, transcription: nil)
        try await store.setEntities([
            JournalEntity(kind: .topic, name: "mornings"),
            JournalEntity(kind: .topic, name: "work"),
            JournalEntity(kind: .person, name: "Sarah"), // not a topic → never suggested
        ], for: entry.id)

        #expect(try await store.suggestedTags(for: entry.id) == ["mornings", "work"])

        try await store.setTags(["work"], for: entry.id) // accepting a topic as a tag
        #expect(try await store.suggestedTags(for: entry.id) == ["mornings"])

        try await store.dismissSuggestion("Mornings", for: entry.id) // case-insensitive
        #expect(try await store.suggestedTags(for: entry.id).isEmpty)
    }

    @Test("dismissing a suggestion for a missing entry throws")
    func dismissMissingThrows() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let ghost = UUID()
        await #expect(throws: JournalStoreError.entryNotFound(ghost)) {
            try await store.dismissSuggestion("x", for: ghost)
        }
    }

    @Test("journal persists across store instances on the same file and key")
    func persistsAcrossInstances() async throws {
        let url = temporaryDatabaseURL()
        let key = StaticKeyProvider(key: SymmetricKey(size: .bits256))
        let entry = makeEntry()
        try await SQLCipherJournalStore(fileURL: url, keyProvider: key).save(entry: entry, transcription: nil)

        let reopened = try SQLCipherJournalStore(fileURL: url, keyProvider: key)

        #expect(try await reopened.allEntries() == [entry])
    }

    @Test("the database file leaks neither entry text nor the SQLite header")
    func fileIsEncryptedAtRest() async throws {
        let url = temporaryDatabaseURL()
        let store = try SQLCipherJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
        try await store.save(entry: makeEntry(text: "the long silence after"), transcription: nil)

        let bytes = try Data(contentsOf: url)

        // SQLCipher encrypts the header too, so the plaintext magic is absent.
        #expect(bytes.range(of: Data("SQLite format 3".utf8)) == nil)
        #expect(bytes.range(of: Data("the long silence after".utf8)) == nil)
    }

    @Test("a wrong key cannot read an existing database")
    func wrongKeyFailsClosed() async throws {
        let url = temporaryDatabaseURL()
        try await SQLCipherJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
            .save(entry: makeEntry(), transcription: nil)

        // A different key must fail — either opening or first read throws.
        await #expect(throws: (any Error).self) {
            let wrong = try SQLCipherJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
            _ = try await wrong.allEntries()
        }
    }
}
