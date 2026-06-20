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
            try record.update(db)
            guard let entry = record.toEntry() else {
                throw JournalStoreError.corruptDatabase
            }
            return entry
        }
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
