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

    @Test("all entries come back newest first")
    func ordersNewestFirst() async throws {
        let store = try SQLCipherJournalStore(fileURL: temporaryDatabaseURL(), keyProvider: StaticKeyProvider.random())
        let older = makeEntry(text: "older", at: Date(timeIntervalSince1970: 1_000))
        let newer = makeEntry(text: "newer", at: Date(timeIntervalSince1970: 2_000))
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
