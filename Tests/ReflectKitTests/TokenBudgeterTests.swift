@testable import ReflectKit
import Testing

@Suite("TokenBudgeter — staying under the 8K window")
struct TokenBudgeterTests {
    @Test("estimation is pessimistic and monotonic")
    func estimationBasics() {
        #expect(TokenBudgeter.estimateTokens("") == 0)
        #expect(TokenBudgeter.estimateTokens("word") == 1)
        #expect(TokenBudgeter.estimateTokens(String(repeating: "a", count: 400)) == 100)
    }

    @Test("short text comes back as a single chunk")
    func shortTextSingleChunk() {
        // Act
        let chunks = TokenBudgeter.chunk("One small moment today.", maxTokens: 100)

        // Assert
        #expect(chunks == ["One small moment today."])
    }

    @Test("a long multi-sentence fixture chunks under budget with no content lost")
    func longFixtureChunksUnderBudget() {
        // Arrange — ~200 sentences, far over a 64-token budget
        let sentence = "The kitchen still smelled like cardamom after everyone left and I stayed up too late again."
        let fixture = Array(repeating: sentence, count: 200).joined(separator: " ")
        let budget = 64

        // Act
        let chunks = TokenBudgeter.chunk(fixture, maxTokens: budget)

        // Assert
        #expect(chunks.count > 1)
        for chunk in chunks {
            #expect(TokenBudgeter.estimateTokens(chunk) <= budget, "chunk over budget: \(chunk.count) chars")
        }
        let rejoined = chunks.joined(separator: " ")
        #expect(rejoined == fixture, "chunking must not lose or reorder words")
    }

    @Test("a single oversized sentence is split by words, all under budget")
    func oversizedSentenceSplits() {
        // Arrange
        let words = Array(repeating: "unbroken", count: 600).joined(separator: " ")

        // Act
        let chunks = TokenBudgeter.chunk(words, maxTokens: 32)

        // Assert
        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { TokenBudgeter.estimateTokens($0) <= 32 })
        #expect(chunks.joined(separator: " ") == words)
    }

    @Test("whitespace-only input yields no chunks")
    func whitespaceYieldsNothing() {
        #expect(TokenBudgeter.chunk("   \n  ", maxTokens: 10).isEmpty)
    }
}
