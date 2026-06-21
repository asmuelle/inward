import Foundation

public enum JournalStoreError: Error, Equatable {
    case keyUnavailable
    case decryptionFailed
    case corruptDatabase
    case entryNotFound(UUID)
    case ioFailure(String)
}

/// Storage boundary for the journal. The M1 implementation is an encrypted file
/// store; a GRDB+SQLCipher store can replace it behind this same protocol.
public protocol JournalStoring: Sendable {
    /// Persists an entry and its optional transcription provenance atomically:
    /// both land or neither does.
    func save(entry: Entry, transcription: Transcription?) async throws

    /// All entries, newest first.
    func allEntries() async throws -> [Entry]

    func entry(id: UUID) async throws -> Entry?

    func transcription(entryID: UUID) async throws -> Transcription?

    /// Replaces the edited text of an entry, returning the new value.
    /// The raw transcript is never touched.
    @discardableResult
    func updateEditedText(entryID: UUID, textEdited: String) async throws -> Entry

    /// Permanently removes an entry and its transcription. Throws `entryNotFound`
    /// if no entry has that id. There is no recovery in the store — the app's only
    /// safety net is the in-session undo it offers around this call.
    func delete(entryID: UUID) async throws

    // MARK: - Tags

    /// Every tag in use across the journal, sorted by name.
    func allTags() async throws -> [Tag]

    /// The tags on one entry, sorted by name.
    func tags(for entryID: UUID) async throws -> [Tag]

    /// Replaces the entry's tags with the given names (normalized; empties and
    /// duplicates dropped). Creates tags that don't exist yet and prunes any that
    /// no entry references anymore. Throws `entryNotFound` if the entry is absent.
    func setTags(_ names: [String], for entryID: UUID) async throws

    /// Entries carrying the given tag (matched on its normalized name), newest first.
    func entries(withTag tagName: String) async throws -> [Entry]
}
