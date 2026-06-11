import Foundation
@testable import RecallKit
import Testing

@Suite("NaiveRecallIndex — deterministic word-overlap retrieval")
struct NaiveRecallIndexTests {
    @Test("the most overlapping entry ranks first")
    func bestOverlapFirst() async {
        // Arrange
        let index = NaiveRecallIndex()
        let aboutWork = UUID()
        let aboutSleep = UUID()
        await index.index(id: aboutWork, text: "Deadline pressure again, the launch meeting ran long")
        await index.index(id: aboutSleep, text: "Slept badly, kept replaying the conversation")

        // Act
        let related = await index.related(to: "another launch deadline and another long meeting")

        // Assert
        #expect(related.first == aboutWork)
    }

    @Test("no overlap means no results — never noise")
    func noOverlapNoResults() async {
        // Arrange
        let index = NaiveRecallIndex()
        await index.index(id: UUID(), text: "garden tomatoes finally ripened")

        // Act
        let related = await index.related(to: "quarterly tax filing spreadsheet")

        // Assert
        #expect(related.isEmpty)
    }

    @Test("results are stable across runs and bounded by limit")
    func stableAndBounded() async {
        // Arrange
        let index = NaiveRecallIndex()
        let ids = (0 ..< 10).map { _ in UUID() }
        for id in ids {
            await index.index(id: id, text: "evening walk by the river with cold hands")
        }

        // Act
        let first = await index.related(to: "walk along the river in the evening", limit: 3)
        let second = await index.related(to: "walk along the river in the evening", limit: 3)

        // Assert
        #expect(first == second)
        #expect(first.count == 3)
    }

    @Test("tokenizer drops short words and punctuation")
    func tokenizerNormalizes() {
        // Act
        let tokens = NaiveRecallIndex.tokenize("It's a no — we go on, AGAIN!")

        // Assert
        #expect(tokens.contains("again"))
        #expect(!tokens.contains("a"))
        #expect(!tokens.contains("we"))
    }

    @Test("empty index reports zero documents")
    func emptyIndexCount() async {
        // Arrange
        let index = NaiveRecallIndex()

        // Assert
        #expect(await index.indexedCount() == 0)
    }
}
