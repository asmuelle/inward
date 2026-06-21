import CryptoKit
import Foundation

/// M1 storage: a single AES-GCM-sealed file holding the whole journal, written
/// atomically with complete file protection on iOS. Nothing readable ever touches
/// disk — the encryption test proves the file is opaque without the key.
///
/// The GRDB+SQLCipher store planned in DESIGN.md replaces this behind the same
/// `JournalStoring` protocol once entry volume warrants a real database.
public actor EncryptedFileJournalStore: JournalStoring {
    private struct EntryTagLink: Codable, Hashable {
        var entryId: UUID
        var tagId: UUID
    }

    private struct JournalDatabase: Codable {
        var schemaVersion: Int
        var entries: [Entry]
        var transcriptions: [Transcription]
        // Optional so archives written before tags decode cleanly (nil → empty).
        var tags: [Tag]?
        var entryTags: [EntryTagLink]?

        static let empty = JournalDatabase(schemaVersion: 1, entries: [], transcriptions: [], tags: [], entryTags: [])
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
        database.entryTags = (database.entryTags ?? []).filter { $0.entryId != entryID }
        database.tags = Self.pruningOrphans(database)
        try persist(database)
    }

    // MARK: - Tags

    public func allTags() async throws -> [Tag] {
        try (loadDatabase().tags ?? []).sorted { $0.name < $1.name }
    }

    public func tags(for entryID: UUID) async throws -> [Tag] {
        let database = try loadDatabase()
        let tagsByID = Dictionary(uniqueKeysWithValues: (database.tags ?? []).map { ($0.id, $0) })
        return (database.entryTags ?? [])
            .filter { $0.entryId == entryID }
            .compactMap { tagsByID[$0.tagId] }
            .sorted { $0.name < $1.name }
    }

    public func setTags(_ names: [String], for entryID: UUID) async throws {
        let normalized = Tag.normalizedNames(names)
        var database = try loadDatabase()
        guard database.entries.contains(where: { $0.id == entryID }) else {
            throw JournalStoreError.entryNotFound(entryID)
        }
        var tags = database.tags ?? []
        var links = (database.entryTags ?? []).filter { $0.entryId != entryID }
        for name in normalized {
            let tag = tags.first { $0.name == name } ?? {
                let created = Tag(name: name)
                tags.append(created)
                return created
            }()
            links.append(EntryTagLink(entryId: entryID, tagId: tag.id))
        }
        database.tags = tags
        database.entryTags = links
        database.tags = Self.pruningOrphans(database)
        try persist(database)
    }

    public func entries(withTag tagName: String) async throws -> [Entry] {
        let name = Tag.normalize(tagName)
        let database = try loadDatabase()
        guard let tag = (database.tags ?? []).first(where: { $0.name == name }) else { return [] }
        let entryIDs = Set((database.entryTags ?? []).filter { $0.tagId == tag.id }.map(\.entryId))
        return database.entries
            .filter { entryIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Tags still referenced by at least one link — the rest are pruned.
    private static func pruningOrphans(_ database: JournalDatabase) -> [Tag] {
        let referenced = Set((database.entryTags ?? []).map(\.tagId))
        return (database.tags ?? []).filter { referenced.contains($0.id) }
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
