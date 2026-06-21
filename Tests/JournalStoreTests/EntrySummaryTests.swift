import Foundation
@testable import JournalStore
import Testing

@Suite("EntrySummary and Entry's precomputed summary")
struct EntrySummaryTests {
    @Test("a multi-sentence entry summarizes to its first sentence")
    func firstSentence() {
        #expect(EntrySummary.make(from: "Garden mornings again. The light was soft.") == "Garden mornings again.")
    }

    @Test("a single long opening is clipped to the max length")
    func clipsLongOpening() {
        let long = String(repeating: "word ", count: 100)
        #expect(EntrySummary.make(from: long).count <= EntrySummary.maxLength)
    }

    @Test("a very short first sentence falls back to the clipped opening")
    func shortSentenceFallsBack() {
        let text = "Hi. Then a much longer second thought that actually carries the meaning."
        #expect(EntrySummary.make(from: text) != "Hi.")
    }

    @Test("blank text summarizes to empty")
    func emptyText() {
        #expect(EntrySummary.make(from: "   \n ") == "")
    }

    @Test("Entry derives and stores its summary at construction")
    func entryDerivesSummary() {
        let entry = Entry(
            createdAt: Date(timeIntervalSince1970: 0),
            source: .text,
            transcriptRaw: "x",
            textEdited: "A calm morning. Coffee outside.",
            locale: "en_US"
        )
        #expect(entry.summary == "A calm morning.")
    }

    @Test("editing the text recomputes the summary")
    func editRecomputes() {
        let entry = Entry(
            createdAt: Date(timeIntervalSince1970: 0),
            source: .text,
            transcriptRaw: "x",
            textEdited: "First thought here.",
            locale: "en_US"
        )
        let edited = entry.withEditedText("A different opening line. More after.", updatedAt: Date(timeIntervalSince1970: 10))
        #expect(edited.summary == "A different opening line.")
        #expect(edited.transcriptRaw == "x", "the raw transcript is never touched")
        #expect(edited.updatedAt == Date(timeIntervalSince1970: 10), "editing advances updatedAt")
    }

    @Test("a fresh entry's updatedAt defaults to its createdAt")
    func updatedAtDefaultsToCreatedAt() {
        let createdAt = Date(timeIntervalSince1970: 5000)
        let entry = Entry(createdAt: createdAt, source: .text, transcriptRaw: "x", textEdited: "Hello there.", locale: "en_US")
        #expect(entry.updatedAt == createdAt)
    }

    @Test("an explicit summary is preserved")
    func explicitSummaryPreserved() {
        let entry = Entry(
            createdAt: Date(timeIntervalSince1970: 0),
            source: .text,
            transcriptRaw: "x",
            textEdited: "whatever the body is",
            summary: "a stored summary",
            locale: "en_US"
        )
        #expect(entry.summary == "a stored summary")
    }

    @Test("decoding an archive written before summaries derives one")
    func decodeWithoutSummaryDerives() throws {
        let json = Data("""
        {"id":"00000000-0000-0000-0000-000000000001","createdAt":0,"source":"text",\
        "transcriptRaw":"x","textEdited":"An older entry. Second part.","locale":"en_US"}
        """.utf8)

        let entry = try JSONDecoder().decode(Entry.self, from: json)

        #expect(entry.summary == "An older entry.")
    }
}
