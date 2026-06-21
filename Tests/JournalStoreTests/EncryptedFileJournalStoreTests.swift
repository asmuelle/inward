import CryptoKit
import Foundation
@testable import JournalStore
import Testing

private func temporaryStoreURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("inward-tests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("journal.inward")
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

@Suite("EncryptedFileJournalStore")
struct EncryptedFileJournalStoreTests {
    @Test("entry and transcription round-trip through one save")
    func saveAndFetchRoundTrip() async throws {
        // Arrange
        let store = EncryptedFileJournalStore(fileURL: temporaryStoreURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        let transcription = Transcription(entryId: entry.id, engine: .mock, confidence: 0.91, completedAt: entry.createdAt)

        // Act
        try await store.save(entry: entry, transcription: transcription)

        // Assert — both halves of the transaction are present
        #expect(try await store.entry(id: entry.id) == entry)
        #expect(try await store.transcription(entryID: entry.id) == transcription)
    }

    @Test("journal persists across store instances on the same file")
    func persistsAcrossInstances() async throws {
        // Arrange
        let url = temporaryStoreURL()
        let key = StaticKeyProvider(key: SymmetricKey(size: .bits256))
        let entry = makeEntry()
        try await EncryptedFileJournalStore(fileURL: url, keyProvider: key)
            .save(entry: entry, transcription: nil)

        // Act
        let reopened = EncryptedFileJournalStore(fileURL: url, keyProvider: key)
        let entries = try await reopened.allEntries()

        // Assert
        #expect(entries == [entry])
    }

    @Test("file on disk leaks neither entry text nor schema names")
    func fileIsOpaqueWithoutKey() async throws {
        // Arrange
        let url = temporaryStoreURL()
        let secret = "the museum visit I never told anyone about"
        let store = EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
        try await store.save(entry: makeEntry(text: secret), transcription: nil)

        // Act
        let raw = try Data(contentsOf: url)

        // Assert — plaintext and JSON structure must be invisible in the ciphertext
        for needle in [secret, "transcriptRaw", "entries", "createdAt"] {
            #expect(!raw.contains(Data(needle.utf8)), "found plaintext: \(needle)")
        }
    }

    @Test("opening with the wrong key fails with decryptionFailed, not garbage data")
    func wrongKeyFailsClosed() async throws {
        // Arrange
        let url = temporaryStoreURL()
        try await EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
            .save(entry: makeEntry(), transcription: nil)
        let intruder = EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())

        // Act / Assert
        await #expect(throws: JournalStoreError.decryptionFailed) {
            _ = try await intruder.allEntries()
        }
    }

    @Test("updateEditedText returns a new value and never touches the raw transcript")
    func editIsImmutableAndPersisted() async throws {
        // Arrange
        let url = temporaryStoreURL()
        let key = StaticKeyProvider(key: SymmetricKey(size: .bits256))
        let store = EncryptedFileJournalStore(fileURL: url, keyProvider: key)
        let original = makeEntry(text: "first words")
        try await store.save(entry: original, transcription: nil)

        // Act
        let updated = try await store.updateEditedText(entryID: original.id, textEdited: "second thoughts")

        // Assert
        #expect(updated.textEdited == "second thoughts")
        #expect(updated.transcriptRaw == "first words")
        #expect(original.textEdited == "first words", "input value must not be mutated")
        let reloaded = try await EncryptedFileJournalStore(fileURL: url, keyProvider: key).entry(id: original.id)
        #expect(reloaded == updated)
    }

    @Test("allEntries returns newest first")
    func entriesSortedNewestFirst() async throws {
        // Arrange
        let store = EncryptedFileJournalStore(fileURL: temporaryStoreURL(), keyProvider: StaticKeyProvider.random())
        let older = makeEntry(text: "older", at: Date(timeIntervalSince1970: 1000))
        let newer = makeEntry(text: "newer", at: Date(timeIntervalSince1970: 2000))
        try await store.save(entry: older, transcription: nil)
        try await store.save(entry: newer, transcription: nil)

        // Act
        let entries = try await store.allEntries()

        // Assert
        #expect(entries.map(\.id) == [newer.id, older.id])
    }

    @Test("unknown entry id reads as nil and updates throw entryNotFound")
    func unknownEntryHandling() async throws {
        // Arrange
        let store = EncryptedFileJournalStore(fileURL: temporaryStoreURL(), keyProvider: StaticKeyProvider.random())
        let ghost = UUID()

        // Act / Assert
        #expect(try await store.entry(id: ghost) == nil)
        await #expect(throws: JournalStoreError.entryNotFound(ghost)) {
            try await store.updateEditedText(entryID: ghost, textEdited: "anything")
        }
        await #expect(throws: JournalStoreError.entryNotFound(ghost)) {
            try await store.delete(entryID: ghost)
        }
    }

    @Test("delete removes the entry and its transcription")
    func deleteRemovesEntryAndTranscription() async throws {
        let store = EncryptedFileJournalStore(fileURL: temporaryStoreURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        let transcription = Transcription(entryId: entry.id, engine: .mock, confidence: 0.9, completedAt: entry.createdAt)
        try await store.save(entry: entry, transcription: transcription)

        try await store.delete(entryID: entry.id)

        #expect(try await store.entry(id: entry.id) == nil)
        #expect(try await store.transcription(entryID: entry.id) == nil)
        #expect(try await store.allEntries().isEmpty)
    }

    @Test("editing advances updatedAt past createdAt")
    func editAdvancesUpdatedAt() async throws {
        let store = EncryptedFileJournalStore(fileURL: temporaryStoreURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        try await store.save(entry: entry, transcription: nil)

        let updated = try await store.updateEditedText(entryID: entry.id, textEdited: "later words")

        #expect(updated.updatedAt > entry.createdAt)
    }

    @Test("tags round-trip (normalized) and filter entries, surviving a reopen")
    func tagsRoundTripAndPersist() async throws {
        let url = temporaryStoreURL()
        let key = StaticKeyProvider(key: SymmetricKey(size: .bits256))
        let store = EncryptedFileJournalStore(fileURL: url, keyProvider: key)
        let newer = makeEntry(text: "a", at: Date(timeIntervalSince1970: 2000))
        let older = makeEntry(text: "b", at: Date(timeIntervalSince1970: 1000))
        try await store.save(entry: newer, transcription: nil)
        try await store.save(entry: older, transcription: nil)
        try await store.setTags(["Work", " work "], for: newer.id)
        try await store.setTags(["home"], for: older.id)

        // Survives a fresh instance reading the sealed file.
        let reopened = EncryptedFileJournalStore(fileURL: url, keyProvider: key)
        #expect(try await reopened.tags(for: newer.id).map(\.name) == ["work"])
        #expect(try await reopened.allTags().map(\.name) == ["home", "work"])
        #expect(try await reopened.entries(withTag: "WORK").map(\.id) == [newer.id])
    }

    @Test("deleting an entry prunes its tags, and tagging a missing entry throws")
    func deletePrunesTagsAndMissingThrows() async throws {
        let store = EncryptedFileJournalStore(fileURL: temporaryStoreURL(), keyProvider: StaticKeyProvider.random())
        let entry = makeEntry()
        try await store.save(entry: entry, transcription: nil)
        try await store.setTags(["solo"], for: entry.id)

        try await store.delete(entryID: entry.id)
        #expect(try await store.allTags().isEmpty)

        let ghost = UUID()
        await #expect(throws: JournalStoreError.entryNotFound(ghost)) {
            try await store.setTags(["x"], for: ghost)
        }
    }

    @Test("empty store reads as empty, not as an error")
    func emptyStoreReadsEmpty() async throws {
        // Arrange
        let store = EncryptedFileJournalStore(fileURL: temporaryStoreURL(), keyProvider: StaticKeyProvider.random())

        // Act / Assert
        #expect(try await store.allEntries().isEmpty)
    }
}
