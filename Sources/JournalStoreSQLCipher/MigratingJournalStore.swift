import Foundation
import JournalStore

/// One-time bridge from the M1 AES-GCM file into the SQLCipher database.
/// Every operation waits for migration, so callers can never observe a partially
/// migrated journal or write into a second store. The legacy file is retained as
/// an encrypted `.migrated` backup only after every entry, transcription, and tag
/// has landed successfully.
public actor MigratingJournalStore: JournalStoring {
    private let destination: any JournalStoring
    private let legacy: any JournalStoring
    private let legacyFileURL: URL
    private var migrationCompleted = false

    public init(destination: any JournalStoring, legacy: any JournalStoring, legacyFileURL: URL) {
        self.destination = destination
        self.legacy = legacy
        self.legacyFileURL = legacyFileURL
    }

    public func save(entry: Entry, transcription: Transcription?) async throws {
        try await ensureMigrated()
        try await destination.save(entry: entry, transcription: transcription)
    }

    public func allEntries() async throws -> [Entry] {
        try await ensureMigrated()
        return try await destination.allEntries()
    }

    public func entry(id: UUID) async throws -> Entry? {
        try await ensureMigrated()
        return try await destination.entry(id: id)
    }

    public func transcription(entryID: UUID) async throws -> Transcription? {
        try await ensureMigrated()
        return try await destination.transcription(entryID: entryID)
    }

    public func updateEditedText(entryID: UUID, textEdited: String) async throws -> Entry {
        try await ensureMigrated()
        return try await destination.updateEditedText(entryID: entryID, textEdited: textEdited)
    }

    public func delete(entryID: UUID) async throws {
        try await ensureMigrated()
        try await destination.delete(entryID: entryID)
    }

    public func allTags() async throws -> [Tag] {
        try await ensureMigrated()
        return try await destination.allTags()
    }

    public func tags(for entryID: UUID) async throws -> [Tag] {
        try await ensureMigrated()
        return try await destination.tags(for: entryID)
    }

    public func setTags(_ names: [String], for entryID: UUID) async throws {
        try await ensureMigrated()
        try await destination.setTags(names, for: entryID)
    }

    public func entries(withTag tagName: String) async throws -> [Entry] {
        try await ensureMigrated()
        return try await destination.entries(withTag: tagName)
    }

    public func setEntities(_ entities: [JournalEntity], for entryID: UUID) async throws {
        try await ensureMigrated()
        try await destination.setEntities(entities, for: entryID)
    }

    public func entities(for entryID: UUID) async throws -> [JournalEntity] {
        try await ensureMigrated()
        return try await destination.entities(for: entryID)
    }

    public func entryIDsNeedingInsights(limit: Int) async throws -> [UUID] {
        try await ensureMigrated()
        return try await destination.entryIDsNeedingInsights(limit: limit)
    }

    public func suggestedTags(for entryID: UUID) async throws -> [String] {
        try await ensureMigrated()
        return try await destination.suggestedTags(for: entryID)
    }

    public func dismissSuggestion(_ name: String, for entryID: UUID) async throws {
        try await ensureMigrated()
        try await destination.dismissSuggestion(name, for: entryID)
    }

    public func entityAssociations() async throws -> [EntityAssociation] {
        try await ensureMigrated()
        return try await destination.entityAssociations()
    }

    public func setEmbedding(_ vector: [Float], for entryID: UUID) async throws {
        try await ensureMigrated()
        try await destination.setEmbedding(vector, for: entryID)
    }

    public func allEmbeddings() async throws -> [EntryEmbedding] {
        try await ensureMigrated()
        return try await destination.allEmbeddings()
    }

    public func entryIDsNeedingEmbedding(limit: Int) async throws -> [UUID] {
        try await ensureMigrated()
        return try await destination.entryIDsNeedingEmbedding(limit: limit)
    }

    private func ensureMigrated() async throws {
        guard !migrationCompleted else { return }
        guard FileManager.default.fileExists(atPath: legacyFileURL.path) else {
            migrationCompleted = true
            return
        }

        let destinationIDs = try await Set(destination.allEntries().map(\.id))
        for entry in try await legacy.allEntries() {
            if !destinationIDs.contains(entry.id) {
                let transcription = try await legacy.transcription(entryID: entry.id)
                try await destination.save(entry: entry, transcription: transcription)
            }
            let tagNames = try await legacy.tags(for: entry.id).map(\.name)
            try await destination.setTags(tagNames, for: entry.id)
        }

        try archiveLegacyFile()
        migrationCompleted = true
    }

    private func archiveLegacyFile() throws {
        let preferred = legacyFileURL.appendingPathExtension("migrated")
        let archiveURL = FileManager.default.fileExists(atPath: preferred.path)
            ? legacyFileURL.appendingPathExtension("migrated-\(UUID().uuidString)")
            : preferred
        do {
            try FileManager.default.moveItem(at: legacyFileURL, to: archiveURL)
        } catch {
            throw JournalStoreError.ioFailure("could not archive migrated journal")
        }
    }
}
