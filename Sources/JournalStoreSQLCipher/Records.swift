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
    var updatedAt: Date?
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
        updatedAt = entry.updatedAt
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
            // Rows created before v3 backfill to createdAt (handled in the initializer).
            updatedAt: updatedAt,
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

struct TagRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tag"

    var id: String
    var name: String
    var createdAt: Date

    init(_ tag: Tag, createdAt: Date) {
        id = tag.id.uuidString
        name = tag.name
        self.createdAt = createdAt
    }

    func toTag() -> Tag? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Tag(id: uuid, name: name)
    }
}

struct EntryTagRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "entry_tag"

    var entryId: String
    var tagId: String
}

struct EntityRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "entity"

    var id: String
    var kind: String
    var name: String
    var normalized: String

    init(_ entity: JournalEntity) {
        id = entity.id.uuidString
        kind = entity.kind.rawValue
        name = entity.name
        normalized = entity.normalizedName
    }

    func toEntity() -> JournalEntity? {
        guard let uuid = UUID(uuidString: id), let kind = EntityKind(rawValue: kind) else { return nil }
        return JournalEntity(id: uuid, kind: kind, name: name)
    }
}

struct EntryEntityRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "entry_entity"

    var entryId: String
    var entityId: String
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
        // Last-edited timestamp. Added nullable, then backfilled to createdAt for
        // existing rows; new rows always set it, so it is never NULL afterward.
        migrator.registerMigration("v3-entry-updatedAt") { db in
            try db.alter(table: EntryRecord.databaseTableName) { t in
                t.add(column: "updatedAt", .datetime)
            }
            try db.execute(sql: "UPDATE \(EntryRecord.databaseTableName) SET updatedAt = createdAt WHERE updatedAt IS NULL")
        }
        // Free-form tags: a tag vocabulary plus a many-to-many join. Both sides
        // cascade — deleting an entry drops its links; pruning a tag drops links too.
        migrator.registerMigration("v4-tags") { db in
            try db.create(table: TagRecord.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull().unique()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: EntryTagRecord.databaseTableName) { t in
                t.column("entryId", .text).notNull().indexed()
                    .references(EntryRecord.databaseTableName, onDelete: .cascade)
                t.column("tagId", .text).notNull().indexed()
                    .references(TagRecord.databaseTableName, onDelete: .cascade)
                t.primaryKey(["entryId", "tagId"])
            }
        }
        // Derived entities (people/places/objects/topics) plus a per-entry marker
        // so the indexer knows what still needs extracting. Both join sides cascade.
        migrator.registerMigration("v5-entities") { db in
            try db.alter(table: EntryRecord.databaseTableName) { t in
                t.add(column: "insightsExtractedAt", .datetime)
            }
            try db.create(table: EntityRecord.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                t.column("name", .text).notNull()
                t.column("normalized", .text).notNull()
                t.uniqueKey(["kind", "normalized"])
            }
            try db.create(table: EntryEntityRecord.databaseTableName) { t in
                t.column("entryId", .text).notNull().indexed()
                    .references(EntryRecord.databaseTableName, onDelete: .cascade)
                t.column("entityId", .text).notNull().indexed()
                    .references(EntityRecord.databaseTableName, onDelete: .cascade)
                t.primaryKey(["entryId", "entityId"])
            }
        }
        return migrator
    }()
}
