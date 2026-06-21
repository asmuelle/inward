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
        let updated = database.entries[index].withEditedText(textEdited, updatedAt: Date())
        database.entries[index] = updated
        try persist(database)
        return updated
    }

    public func delete(entryID: UUID) async throws {
        var database = try loadDatabase()
        guard let index = database.entries.firstIndex(where: { $0.id == entryID }) else {
            throw JournalStoreError.entryNotFound(entryID)
        }
        database.entries.remove(at: index)
        database.transcriptions.removeAll { $0.entryId == entryID }
        try persist(database)
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
            decoder.dateDecodingStrategy = Self.dateDecoding
            let database = try decoder.decode(JournalDatabase.self, from: plaintext)
            cache = database
            return database
        } catch {
            throw JournalStoreError.corruptDatabase
        }
    }

    private func persist(_ database: JournalDatabase) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = Self.dateEncoding
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

    // MARK: - Date coding

    /// ISO8601DateFormatter is thread-safe for date<->string conversion, so sharing
    /// one instance across isolation domains is safe — hence nonisolated(unsafe).
    /// Used only to read pre-existing ISO-8601 archives (see `dateDecoding`).
    private nonisolated(unsafe) static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let iso8601Plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Store the raw time interval so any Date — including a sub-second `Date()` —
    /// reads back bit-for-bit, which ISO-8601 strings (even at millisecond
    /// resolution) cannot guarantee.
    private static let dateEncoding = JSONEncoder.DateEncodingStrategy.custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(date.timeIntervalSinceReferenceDate)
    }

    /// Reads the new numeric form, and still parses pre-existing ISO-8601 archives.
    private static let dateDecoding = JSONDecoder.DateDecodingStrategy.custom { decoder in
        let container = try decoder.singleValueContainer()
        if let interval = try? container.decode(Double.self) {
            return Date(timeIntervalSinceReferenceDate: interval)
        }
        let raw = try container.decode(String.self)
        if let date = iso8601Fractional.date(from: raw) ?? iso8601Plain.date(from: raw) {
            return date
        }
        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Unrecognized date: \(raw)")
        )
    }
}
