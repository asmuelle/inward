import Foundation
@testable import JournalStore
import Testing

@Suite("UnavailableJournalStore — fail closed")
struct UnavailableJournalStoreTests {
    @Test("reads and writes preserve the database error instead of creating data")
    func readsAndWritesFail() async {
        let expected = JournalStoreError.corruptDatabase
        let store = UnavailableJournalStore(error: expected)
        let entry = Entry(
            createdAt: Date(),
            source: .text,
            transcriptRaw: "kept",
            textEdited: "kept",
            locale: "en_US"
        )

        await #expect(throws: expected) { try await store.allEntries() }
        await #expect(throws: expected) { try await store.save(entry: entry, transcription: nil) }
    }
}
