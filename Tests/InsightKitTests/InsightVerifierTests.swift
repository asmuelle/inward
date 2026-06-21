import Foundation
@testable import InsightKit
import Testing

@Suite("InsightVerifier — entities must occur in the user's own words")
struct InsightVerifierTests {
    @Test("a fabricated entity not in the text is dropped; a present one is kept")
    func dropsFabricated() {
        let insights = EntryInsights(people: ["Sarah", "Napoleon"], places: ["Berlin"])
        let text = "I walked through Berlin with Sarah."

        let verified = InsightVerifier.verified(insights, against: text)

        #expect(verified.people == ["Sarah"])
        #expect(verified.places == ["Berlin"])
    }

    @Test("matching is whole-word — a substring of a longer word doesn't count")
    func wholeWordOnly() {
        let insights = EntryInsights(people: ["art"]) // appears only inside "Bartholomew"
        let verified = InsightVerifier.verified(insights, against: "Bartholomew called today.")
        #expect(verified.people.isEmpty)
    }

    @Test("matching ignores case and diacritics")
    func caseAndDiacriticInsensitive() {
        let insights = EntryInsights(places: ["zurich"])
        let verified = InsightVerifier.verified(insights, against: "A long day in Zürich.")
        #expect(verified.places == ["zurich"])
    }

    @Test("entities are deduped case-insensitively, preserving first casing")
    func dedupes() {
        let insights = EntryInsights(people: ["Sam", "sam", "SAM"])
        let verified = InsightVerifier.verified(insights, against: "Sam, Sam, and Sam again.")
        #expect(verified.people == ["Sam"])
    }

    @Test("topics, sentiment, and action items pass through (trimmed); empty sentiment becomes nil")
    func interpretationPassesThrough() {
        let insights = EntryInsights(
            topics: [" mornings ", "mornings", ""],
            sentiment: "  ",
            actionItems: ["call mum"]
        )
        let verified = InsightVerifier.verified(insights, against: "anything")
        #expect(verified.topics == ["mornings"])
        #expect(verified.sentiment == nil)
        #expect(verified.actionItems == ["call mum"])
    }
}

#if canImport(NaturalLanguage)
    @Suite("NaturalLanguageEntityExtractor — deterministic on-device floor")
    struct NaturalLanguageEntityExtractorTests {
        private let extractor = NaturalLanguageEntityExtractor()

        @Test("is always available")
        func available() async {
            #expect(await extractor.availability() == .available)
        }

        @Test("empty text yields empty insights")
        func emptyText() async throws {
            let result = try await extractor.extract(
                from: ExtractableEntry(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), text: "   ")
            )
            #expect(result == .empty)
        }

        @Test("every extracted entity occurs in the entry — verification is a no-op")
        func entitiesAreGroundedInText() async throws {
            let text = "I met Sarah in Berlin and we talked for hours."
            let entry = ExtractableEntry(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), text: text)

            let raw = try await extractor.extract(from: entry)
            let verified = InsightVerifier.verified(raw, against: text)

            // The NL floor only ever returns substrings of the text, so verifying
            // its concrete entities must not remove any of them.
            #expect(Set(verified.entities) == Set(raw.entities))
        }

        @Test("sentiment is nil or one of the calm words")
        func sentimentVocabulary() async throws {
            let entry = ExtractableEntry(
                id: UUID(),
                createdAt: Date(timeIntervalSince1970: 0),
                text: "Today was wonderful and bright and full of small joys."
            )
            let result = try await extractor.extract(from: entry)
            if let sentiment = result.sentiment {
                #expect(["heavy", "steady", "light"].contains(sentiment))
            }
        }
    }
#endif
