import Foundation

/// Fail-closed store used when the encrypted database cannot be opened. It never
/// creates a second journal or accepts writes; the app can surface the typed error
/// and preserve the original database for recovery.
public struct UnavailableJournalStore: JournalStoring {
    private let error: JournalStoreError

    public init(error: JournalStoreError) {
        self.error = error
    }

    public func save(entry _: Entry, transcription _: Transcription?) async throws {
        throw error
    }

    public func allEntries() async throws -> [Entry] {
        throw error
    }

    public func entry(id _: UUID) async throws -> Entry? {
        throw error
    }

    public func transcription(entryID _: UUID) async throws -> Transcription? {
        throw error
    }

    public func updateEditedText(entryID _: UUID, textEdited _: String) async throws -> Entry {
        throw error
    }

    public func delete(entryID _: UUID) async throws {
        throw error
    }

    public func allTags() async throws -> [Tag] {
        throw error
    }

    public func tags(for _: UUID) async throws -> [Tag] {
        throw error
    }

    public func setTags(_: [String], for _: UUID) async throws {
        throw error
    }

    public func entries(withTag _: String) async throws -> [Entry] {
        throw error
    }

    public func setEntities(_: [JournalEntity], for _: UUID) async throws {
        throw error
    }

    public func entities(for _: UUID) async throws -> [JournalEntity] {
        throw error
    }

    public func entryIDsNeedingInsights(limit _: Int) async throws -> [UUID] {
        throw error
    }

    public func suggestedTags(for _: UUID) async throws -> [String] {
        throw error
    }

    public func dismissSuggestion(_: String, for _: UUID) async throws {
        throw error
    }

    public func entityAssociations() async throws -> [EntityAssociation] {
        throw error
    }

    public func setEmbedding(_: [Float], for _: UUID) async throws {
        throw error
    }

    public func allEmbeddings() async throws -> [EntryEmbedding] {
        throw error
    }

    public func entryIDsNeedingEmbedding(limit _: Int) async throws -> [UUID] {
        throw error
    }
}
