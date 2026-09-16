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

@Suite("TokenBudgeter — accounting against the real context size")
struct TokenAccountingTests {
    @Test("prompt budget is the context minus instructions and a response reserve, never below one")
    func promptBudgetSubtractsOverheads() {
        #expect(TokenBudgeter.promptBudget(contextSize: 4096, instructionTokens: 96, responseReserve: 500) == 3500)
        #expect(TokenBudgeter.promptBudget(contextSize: 100, instructionTokens: 90, responseReserve: 90) == 1)
    }

    @Test("a calibrated ratio makes estimation stricter, never looser than the default")
    func calibratedEstimateIsStricter() {
        let text = String(repeating: "a", count: 400)

        #expect(TokenBudgeter.estimateTokens(text, charactersPerToken: 2) == 200)
        #expect(TokenBudgeter.estimateTokens(text, charactersPerToken: 4) == 100)
    }

    @Test("rebudgeting after an overflow scales the budget by how far the model overshot")
    func rebudgetScalesByOvershoot() {
        // Arrange — the model reported 5000 tokens against a 4096 context.
        let next = TokenBudgeter.rebudget(3500, contextSize: 4096, tokenCount: 5000)

        // Assert — strictly smaller, and below the raw ratio (3500 * 4096 / 5000 ≈ 2867) with headroom.
        #expect(next < 3500)
        #expect(next < 2867)
        #expect(next > 1000)
    }

    @Test("rebudgeting without a usable token count halves the budget")
    func rebudgetWithoutCountHalves() {
        #expect(TokenBudgeter.rebudget(3000, contextSize: 4096, tokenCount: 0) == 1500)
        #expect(TokenBudgeter.rebudget(3000, contextSize: 4096, tokenCount: 4000) == 1500)
        #expect(TokenBudgeter.rebudget(1, contextSize: 4096, tokenCount: 0) == 1)
    }

    @Test("calibration takes the most pessimistic observed ratio, floored at one")
    func calibrationIsPessimistic() {
        // Arrange
        let observations = [
            TokenUsageObservation(promptCharacters: 4000, inputTokens: 1000, outputTokens: 50), // 4.0
            TokenUsageObservation(promptCharacters: 3000, inputTokens: 1200, outputTokens: 50), // 2.5
            TokenUsageObservation(promptCharacters: 0, inputTokens: 0, outputTokens: 0), // ignored
        ]

        // Act
        let ratio = TokenBudgeter.calibratedCharactersPerToken(from: observations)

        // Assert — 2.5 rounds down to 2
        #expect(ratio == 2)
        #expect(TokenBudgeter.calibratedCharactersPerToken(from: []) == TokenBudgeter.charactersPerToken)
        #expect(TokenBudgeter.calibratedCharactersPerToken(from: [.init(
            promptCharacters: 10,
            inputTokens: 100,
            outputTokens: 1
        )]) == 1)
    }

    @Test("the ledger keeps a bounded window of observations and calibrates from them")
    func ledgerIsBoundedAndCalibrates() async {
        // Arrange
        let ledger = TokenUsageLedger(capacity: 3)
        for index in 0 ..< 5 {
            await ledger.record(TokenUsageObservation(promptCharacters: 4000, inputTokens: 1000 + index, outputTokens: 10))
        }

        // Act
        let snapshot = await ledger.snapshot()
        let ratio = await ledger.calibratedCharactersPerToken()

        // Assert — only the last three survive; 4000 / 1004 ≈ 3.98 → 3
        #expect(snapshot.count == 3)
        #expect(snapshot.first?.inputTokens == 1002)
        #expect(ratio == 3)
    }
}
