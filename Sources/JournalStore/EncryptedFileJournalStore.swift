import CryptoKit
import Foundation

/// M1 storage: a single AES-GCM-sealed file holding the whole journal, written
/// atomically with complete file protection on iOS. Nothing readable ever touches
/// disk — the encryption test proves the file is opaque without the key.
///
/// The GRDB+SQLCipher store planned in DESIGN.md replaces this behind the same
/// `JournalStoring` protocol once entry volume warrants a real database.
public actor EncryptedFileJournalStore: JournalStoring {
    private struct JournalDatabase: Codable {
        var schemaVersion: Int
        var entries: [Entry]
        var transcriptions: [Transcription]

        static let empty = JournalDatabase(schemaVersion: 1, entries: [], transcriptions: [])
    }

    private let fileURL: URL
    private let keyProvider: any KeyProviding
    private var cache: JournalDatabase?

    public init(fileURL: URL, keyProvider: any KeyProviding) {
        self.fileURL = fileURL
        self.keyProvider = keyProvider
    }

    // MARK: - JournalStoring

    public func save(entry: Entry, transcription: Transcription?) async throws {
        var database = try loadDatabase()
        database.entries.append(entry)
        if let transcription {
            database.transcriptions.append(transcription)
        }
        try persist(database)
    }

    public func allEntries() async throws -> [Entry] {
        try loadDatabase().entries.sorted { $0.createdAt > $1.createdAt }
    }

    public func entry(id: UUID) async throws -> Entry? {
        try loadDatabase().entries.first { $0.id == id }
    }

    public func transcription(entryID: UUID) async throws -> Transcription? {
        try loadDatabase().transcriptions.first { $0.entryId == entryID }
    }

    @discardableResult
    public func updateEditedText(entryID: UUID, textEdited: String) async throws -> Entry {
        var database = try loadDatabase()
        guard let index = database.entries.firstIndex(where: { $0.id == entryID }) else {
            throw JournalStoreError.entryNotFound(entryID)
        }
        let updated = database.entries[index].withEditedText(textEdited)
        database.entries[index] = updated
        try persist(database)
        return updated
    }

    // MARK: - Sealed file handling

    private func loadDatabase() throws -> JournalDatabase {
        if let cache { return cache }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cache = .empty
            return .empty
        }

        let sealed: Data
        do {
            sealed = try Data(contentsOf: fileURL)
        } catch {
            throw JournalStoreError.ioFailure(error.localizedDescription)
        }

        let plaintext: Data
        do {
            let box = try AES.GCM.SealedBox(combined: sealed)
            plaintext = try AES.GCM.open(box, using: keyProvider.key())
        } catch let error as JournalStoreError {
            throw error
        } catch {
            throw JournalStoreError.decryptionFailed
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let database = try decoder.decode(JournalDatabase.self, from: plaintext)
            cache = database
            return database
        } catch {
            throw JournalStoreError.corruptDatabase
        }
    }

    private func persist(_ database: JournalDatabase) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let plaintext: Data
        do {
            plaintext = try encoder.encode(database)
        } catch {
            throw JournalStoreError.ioFailure(error.localizedDescription)
        }

        do {
            let sealed = try AES.GCM.seal(plaintext, using: keyProvider.key())
            guard let combined = sealed.combined else { throw JournalStoreError.ioFailure("sealing produced no data") }
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try combined.write(to: fileURL, options: writeOptions)
            cache = database
        } catch let error as JournalStoreError {
            throw error
        } catch {
            throw JournalStoreError.ioFailure(error.localizedDescription)
        }
    }

    private var writeOptions: Data.WritingOptions {
        #if os(iOS)
            [.atomic, .completeFileProtection]
        #else
            [.atomic]
        #endif
    }
}
