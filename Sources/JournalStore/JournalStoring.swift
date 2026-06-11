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
}
