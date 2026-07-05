@testable import CaptureKit
import Foundation
import SafetyKit
import Testing

@Suite("CaptureSummaryPipeline — gate first, validate after")
struct CaptureSummaryPipelineTests {
    @Test("a clear entry returns the model's recap")
    func summaryHappyPath() async {
        // Arrange
        let provider = MockCaptureSummaryProvider(summary: "You described the long walk home.")
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.summarize("I took the long way home tonight.")

        // Assert
        #expect(outcome == .summary("You described the long walk home."))
    }

    @Test("asking to expand returns the model's open question")
    func clarificationHappyPath() async {
        // Arrange
        let provider = MockCaptureSummaryProvider(clarification: "What made you choose the long way?")
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.clarify("I took the long way home tonight.")

        // Assert
        #expect(outcome == .question("What made you choose the long way?"))
    }

    @Test("crisis content suppresses the model entirely and surfaces resources")
    func crisisSuppressesSummary() async {
        // Arrange — the model would happily summarize, but the gate must fire first.
        let provider = MockCaptureSummaryProvider(summary: "should never be spoken")
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.summarize("Some days I just want to die.")

        // Assert
        guard case let .suppressed(resources) = outcome else {
            Issue.record("expected suppressed, got \(outcome)")
            return
        }
        #expect(!resources.isEmpty)
    }

    @Test("crisis content also suppresses the clarification path")
    func crisisSuppressesClarification() async {
        // Arrange
        let provider = MockCaptureSummaryProvider()
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.clarify("I want to die.")

        // Assert
        guard case .suppressed = outcome else {
            Issue.record("expected suppressed, got \(outcome)")
            return
        }
    }

    @Test("regulated vocabulary in model output is rejected, never spoken")
    func bannedTermRejectsOutput() async {
        // Arrange — the model returns a recap containing a clinical term.
        let provider = MockCaptureSummaryProvider(summary: "This sounds like it needs a diagnosis.")
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.summarize("I felt off all day.")

        // Assert — discarded, not surfaced.
        #expect(outcome == .unavailable)
    }

    @Test("an unavailable model degrades to unavailable, not an error")
    func unavailableModelDegrades() async {
        // Arrange
        let provider = MockCaptureSummaryProvider(availability: .unavailable(reason: "no AI"))
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.summarize("anything")

        // Assert
        #expect(outcome == .unavailable)
    }

    @Test("a throwing provider degrades to unavailable")
    func throwingProviderDegrades() async {
        // Arrange
        let provider = MockCaptureSummaryProvider(shouldThrow: true)
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.summarize("anything")

        // Assert
        #expect(outcome == .unavailable)
    }

    @Test("empty model output is treated as unavailable")
    func emptyOutputDegrades() async {
        // Arrange
        let provider = MockCaptureSummaryProvider(summary: "   ")
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.summarize("anything")

        // Assert
        #expect(outcome == .unavailable)
    }
}

@Suite("DeterministicCaptureSummaryProvider — the offline fallback")
struct DeterministicCaptureSummaryProviderTests {
    @Test("summary echoes the person's own first sentence, runs through the pipeline")
    func deterministicSummaryThroughPipeline() async {
        // Arrange
        let provider = DeterministicCaptureSummaryProvider()
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.summarize("The meeting ran long. I felt unheard.")

        // Assert — first-sentence truncation, validated and surfaced.
        #expect(outcome == .summary("The meeting ran long."))
    }

    @Test("clarification returns the injected (localizable) prompt")
    func deterministicClarification() async {
        // Arrange
        let provider = DeterministicCaptureSummaryProvider(clarificationQuestion: "Was möchtest du noch sagen?")
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.clarify("Heute war anstrengend.")

        // Assert
        #expect(outcome == .question("Was möchtest du noch sagen?"))
    }

    @Test("the deterministic provider still defers to the crisis gate")
    func deterministicRespectsCrisisGate() async {
        // Arrange
        let provider = DeterministicCaptureSummaryProvider()
        let pipeline = CaptureSummaryPipeline(provider: provider)

        // Act
        let outcome = await pipeline.summarize("I want to die.")

        // Assert
        guard case .suppressed = outcome else {
            Issue.record("expected suppressed, got \(outcome)")
            return
        }
    }
}
