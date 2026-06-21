import Foundation
import GRDB
import JournalStore

/// The shipped journal store: a real SQLite database encrypted at rest by
/// SQLCipher, with the key supplied (never stored) by a `KeyProviding`. Replaces
/// the M1 whole-file `EncryptedFileJournalStore` behind the same `JournalStoring`
/// protocol — callers are untouched — and gains incremental writes and queries
/// instead of re-encrypting the entire journal on every save.
///
/// Satisfies invariant #4: the database is SQLCipher-encrypted and, on iOS, the
/// containing directory carries complete file protection so all of db/-wal/-shm
/// inherit it.
public final class SQLCipherJournalStore: JournalStoring {
    private let dbQueue: DatabaseQueue

    public init(fileURL: URL, keyProvider: any KeyProviding) throws {
        let keyData = try keyProvider.key().withUnsafeBytes { Data($0) }
        try Self.prepareDirectory(fileURL.deletingLastPathComponent())

        var configuration = Configuration()
        // SQLCipher takes the key here, on every connection, before any I/O.
        configuration.prepareDatabase { db in
            try db.usePassphrase(keyData)
        }

        do {
            dbQueue = try DatabaseQueue(path: fileURL.path, configuration: configuration)
            try JournalSchema.migrator.migrate(dbQueue)
        } catch {
            throw JournalStoreError.ioFailure(String(describing: error))
        }
    }

    // MARK: - JournalStoring

    public func save(entry: Entry, transcription: Transcription?) async throws {
        try await write { db in
            try EntryRecord(entry).insert(db)
            if let transcription {
                try TranscriptionRecord(transcription).insert(db)
            }
        }
    }

    public func allEntries() async throws -> [Entry] {
        try await read { db in
            try EntryRecord
                .order(Column("createdAt").desc)
                .fetchAll(db)
                .compactMap { $0.toEntry() }
        }
    }

    public func entry(id: UUID) async throws -> Entry? {
        try await read { db in
            try EntryRecord.fetchOne(db, key: id.uuidString)?.toEntry()
        }
    }

    public func transcription(entryID: UUID) async throws -> Transcription? {
        try await read { db in
            try TranscriptionRecord.fetchOne(db, key: entryID.uuidString)?.toTranscription()
        }
    }

    @discardableResult
    public func updateEditedText(entryID: UUID, textEdited: String) async throws -> Entry {
        try await write { db in
            guard var record = try EntryRecord.fetchOne(db, key: entryID.uuidString) else {
                throw JournalStoreError.entryNotFound(entryID)
            }
            record.textEdited = textEdited
            // Keep the precomputed summary in step with the edit, and advance the
            // last-edited timestamp. The raw transcript is provenance — untouched.
            record.summary = EntrySummary.make(from: textEdited)
            record.updatedAt = Date()
            try record.update(db)
            guard let entry = record.toEntry() else {
                throw JournalStoreError.corruptDatabase
            }
            return entry
        }
    }

    public func delete(entryID: UUID) async throws {
        try await write { db in
            // The transcription, entry_tag and entry_entity rows cascade automatically.
            let deleted = try EntryRecord.deleteOne(db, key: entryID.uuidString)
            guard deleted else { throw JournalStoreError.entryNotFound(entryID) }
            try Self.pruneOrphanTags(db)
            try Self.pruneOrphanEntities(db)
        }
    }

    // MARK: - Tags

    public func allTags() async throws -> [Tag] {
        try await read { db in
            try TagRecord.order(Column("name")).fetchAll(db).compactMap { $0.toTag() }
        }
    }

    public func tags(for entryID: UUID) async throws -> [Tag] {
        try await read { db in
            try TagRecord.fetchAll(db, sql: """
                SELECT tag.* FROM tag
                JOIN entry_tag ON entry_tag.tagId = tag.id
                WHERE entry_tag.entryId = ?
                ORDER BY tag.name
            """, arguments: [entryID.uuidString]).compactMap { $0.toTag() }
        }
    }

    public func setTags(_ names: [String], for entryID: UUID) async throws {
        let normalized = Tag.normalizedNames(names)
        try await write { db in
            guard try EntryRecord.fetchOne(db, key: entryID.uuidString) != nil else {
                throw JournalStoreError.entryNotFound(entryID)
            }
            // Replace this entry's links, reusing existing tags and creating new ones.
            try EntryTagRecord.filter(Column("entryId") == entryID.uuidString).deleteAll(db)
            for name in normalized {
                let tagId: String
                if let existing = try TagRecord.filter(Column("name") == name).fetchOne(db) {
                    tagId = existing.id
                } else {
                    let tag = Tag(name: name)
                    try TagRecord(tag, createdAt: Date()).insert(db)
                    tagId = tag.id.uuidString
                }
                try EntryTagRecord(entryId: entryID.uuidString, tagId: tagId).insert(db)
            }
            try Self.pruneOrphanTags(db)
        }
    }

    public func entries(withTag tagName: String) async throws -> [Entry] {
        let name = Tag.normalize(tagName)
        return try await read { db in
            try EntryRecord.fetchAll(db, sql: """
                SELECT entry.* FROM entry
                JOIN entry_tag ON entry_tag.entryId = entry.id
                JOIN tag ON tag.id = entry_tag.tagId
                WHERE tag.name = ?
                ORDER BY entry.createdAt DESC
            """, arguments: [name]).compactMap { $0.toEntry() }
        }
    }

    /// Removes tags no entry references anymore, keeping the vocabulary tidy.
    private static func pruneOrphanTags(_ db: Database) throws {
        try db
            .execute(
                sql: "DELETE FROM \(TagRecord.databaseTableName) WHERE id NOT IN (SELECT tagId FROM \(EntryTagRecord.databaseTableName))"
            )
    }

    // MARK: - Derived entities (insights)

    public func setEntities(_ entities: [JournalEntity], for entryID: UUID) async throws {
        // Dedup by (kind, normalized) so a repeated mention links only once.
        var seen = Set<String>()
        let unique = entities.filter { entity in
            guard !entity.normalizedName.isEmpty else { return false }
            return seen.insert(entity.kind.rawValue + "\u{1}" + entity.normalizedName).inserted
        }
        try await write { db in
            guard try EntryRecord.fetchOne(db, key: entryID.uuidString) != nil else {
                throw JournalStoreError.entryNotFound(entryID)
            }
            try EntryEntityRecord.filter(Column("entryId") == entryID.uuidString).deleteAll(db)
            for entity in unique {
                let entityId: String
                if let existing = try EntityRecord
                    .filter(Column("kind") == entity.kind.rawValue && Column("normalized") == entity.normalizedName)
                    .fetchOne(db)
                {
                    entityId = existing.id
                } else {
                    let record = EntityRecord(entity)
                    try record.insert(db)
                    entityId = record.id
                }
                try EntryEntityRecord(entryId: entryID.uuidString, entityId: entityId).insert(db)
            }
            try Self.pruneOrphanEntities(db)
            // Mark processed even when empty, so the entry isn't re-queued.
            try db.execute(
                sql: "UPDATE \(EntryRecord.databaseTableName) SET insightsExtractedAt = ? WHERE id = ?",
                arguments: [Date(), entryID.uuidString]
            )
        }
    }

    public func entities(for entryID: UUID) async throws -> [JournalEntity] {
        try await read { db in
            try EntityRecord.fetchAll(db, sql: """
                SELECT entity.* FROM entity
                JOIN entry_entity ON entry_entity.entityId = entity.id
                WHERE entry_entity.entryId = ?
                ORDER BY entity.kind, entity.name
            """, arguments: [entryID.uuidString]).compactMap { $0.toEntity() }
        }
    }

    public func entryIDsNeedingInsights(limit: Int) async throws -> [UUID] {
        try await read { db in
            try String.fetchAll(db, sql: """
                SELECT id FROM \(EntryRecord.databaseTableName)
                WHERE insightsExtractedAt IS NULL
                ORDER BY createdAt DESC
                LIMIT ?
            """, arguments: [limit]).compactMap(UUID.init(uuidString:))
        }
    }

    private static func pruneOrphanEntities(_ db: Database) throws {
        try db.execute(
            sql: "DELETE FROM \(EntityRecord.databaseTableName) WHERE id NOT IN (SELECT entityId FROM \(EntryEntityRecord.databaseTableName))"
        )
    }

    // MARK: - Helpers

    /// Wrap GRDB errors as `JournalStoreError`, but let our own typed errors
    /// (entryNotFound, corruptDatabase) pass through untouched.
    private func read<T: Sendable>(_ body: @Sendable @escaping (Database) throws -> T) async throws -> T {
        do {
            return try await dbQueue.read(body)
        } catch let error as JournalStoreError {
            throw error
        } catch {
            throw JournalStoreError.ioFailure(String(describing: error))
        }
    }

    private func write<T: Sendable>(_ body: @Sendable @escaping (Database) throws -> T) async throws -> T {
        do {
            return try await dbQueue.write(body)
        } catch let error as JournalStoreError {
            throw error
        } catch {
            throw JournalStoreError.ioFailure(String(describing: error))
        }
    }

    private static func prepareDirectory(_ directory: URL) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            #if os(iOS)
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: directory.path
                )
            #endif
        } catch {
            throw JournalStoreError.ioFailure(String(describing: error))
        }
    }
}
