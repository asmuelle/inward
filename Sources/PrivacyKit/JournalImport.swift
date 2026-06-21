import Foundation
import JournalStore

/// The merge policy for importing a restored archive into an existing journal:
/// an additive union by entry id. Entries the device already has are left
/// untouched — so importing the same backup twice is a no-op and never
/// overwrites a local edit — and because the store inserts (no upsert), skipping
/// known ids is also what keeps a re-import from colliding on the primary key.
///
/// Pure and store-free so the policy is testable on its own; `ImportModel` reads
/// the existing ids from the store, applies this, and writes the result back.
public enum JournalImporter {
    /// One entry to add, paired with its transcription when the archive carried one.
    public struct Addition: Sendable, Equatable {
        public let entry: Entry
        public let transcription: Transcription?

        public init(entry: Entry, transcription: Transcription?) {
            self.entry = entry
            self.transcription = transcription
        }
    }

    /// The entries in `payload` that `existingIDs` does not already contain, each
    /// paired with its transcription (matched by entry id) when present. Source
    /// order is preserved so a restore reads back in the order it was exported.
    public static func additions(
        from payload: ExportPayload,
        existingIDs: Set<UUID>
    ) -> [Addition] {
        let transcriptionByEntry = Dictionary(
            payload.transcriptions.map { ($0.entryId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return payload.entries
            .filter { !existingIDs.contains($0.id) }
            .map { Addition(entry: $0, transcription: transcriptionByEntry[$0.id]) }
    }
}
