import Foundation
import GRDB
import JournalStore

/// GRDB row for an entry. Kept internal to this module so `JournalStore` stays
/// free of any database dependency — the public types cross the boundary as the
/// plain `Entry`/`Transcription` value types.
struct EntryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "entry"

    var id: String
    var createdAt: Date
    var source: String
    var audioFileRef: String?
    var transcriptRaw: String
    var textEdited: String
    var summary: String
    var durationSec: Double?
    var mood: String?
    var locale: String

    init(_ entry: Entry) {
        id = entry.id.uuidString
        createdAt = entry.createdAt
        source = entry.source.rawValue
        audioFileRef = entry.audioFileRef
        transcriptRaw = entry.transcriptRaw
        textEdited = entry.textEdited
        summary = entry.summary
        durationSec = entry.durationSec
        mood = entry.mood
        locale = entry.locale
    }

    /// Returns nil if the row is malformed (bad UUID or unknown source) so the
    /// store can skip it rather than crash on corrupt data.
    func toEntry() -> Entry? {
        guard let uuid = UUID(uuidString: id), let source = Entry.Source(rawValue: source) else {
            return nil
        }
        return Entry(
            id: uuid,
            createdAt: createdAt,
            source: source,
            audioFileRef: audioFileRef,
            transcriptRaw: transcriptRaw,
            textEdited: textEdited,
            summary: summary,
            durationSec: durationSec,
            mood: mood,
            locale: locale
        )
    }
}

struct TranscriptionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "transcription"

    var entryId: String
    var engine: String
    var confidence: Double
    var completedAt: Date

    init(_ transcription: Transcription) {
        entryId = transcription.entryId.uuidString
        engine = transcription.engine.rawValue
        confidence = transcription.confidence
        completedAt = transcription.completedAt
    }

    func toTranscription() -> Transcription? {
        guard let uuid = UUID(uuidString: entryId), let engine = Transcription.Engine(rawValue: engine) else {
            return nil
        }
        return Transcription(entryId: uuid, engine: engine, confidence: confidence, completedAt: completedAt)
    }
}

enum JournalSchema {
    static let migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: EntryRecord.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("createdAt", .datetime).notNull().indexed()
                t.column("source", .text).notNull()
                t.column("audioFileRef", .text)
                t.column("transcriptRaw", .text).notNull()
                t.column("textEdited", .text).notNull()
                t.column("durationSec", .double)
                t.column("mood", .text)
                t.column("locale", .text).notNull()
            }
            // One transcription per entry; cascades with its entry.
            try db.create(table: TranscriptionRecord.databaseTableName) { t in
                t.primaryKey("entryId", .text)
                    .references(EntryRecord.databaseTableName, onDelete: .cascade)
                t.column("engine", .text).notNull()
                t.column("confidence", .double).notNull()
                t.column("completedAt", .datetime).notNull()
            }
        }
        // Precomputed per-entry summary. Existing rows backfill to empty; they are
        // re-summarized whenever their text is next edited.
        migrator.registerMigration("v2-entry-summary") { db in
            try db.alter(table: EntryRecord.databaseTableName) { t in
                t.add(column: "summary", .text).notNull().defaults(to: "")
            }
        }
        return migrator
    }()
}
