import Foundation
@testable import ReflectKit
import SafetyKit
import Testing

/// Counts invocations so tests can prove the model was never consulted.
private actor CountingProvider: ReflectionProviding {
    private(set) var invocations = 0
    private let result: ReflectionPrompt

    init(result: ReflectionPrompt = ReflectionPrompt(questions: ["What stayed with you?"], themes: ["evening"])) {
        self.result = result
    }

    nonisolated func availability() async -> ReflectionAvailability {
        .available
    }

    func reflection(for _: String) async throws -> ReflectionPrompt {
        invocations += 1
        return result
    }
}

private struct ThrowingProvider: ReflectionProviding {
    func availability() async -> ReflectionAvailability {
        .available
    }

    func reflection(for _: String) async throws -> ReflectionPrompt {
        throw ReflectionError.generationFailed("simulated")
    }
}

private struct UnavailableProvider: ReflectionProviding {
    func availability() async -> ReflectionAvailability {
        .unavailable(reason: "no apple intelligence")
    }

    func reflection(for _: String) async throws -> ReflectionPrompt {
        Issue.record("must not be called when unavailable")
        throw ReflectionError.modelUnavailable
    }
}

@Suite("ReflectionPipeline — gate before model, validation after")
struct ReflectionPipelineTests {
    @Test("crisis text suppresses the model entirely and surfaces static resources")
    func crisisSuppressesModel() async {
        // Arrange
        let provider = CountingProvider()
        let pipeline = ReflectionPipeline(provider: provider)

        // Act
        let outcome = await pipeline.reflect(on: "I have been thinking about how to end my life")

        // Assert
        guard case let .suppressed(resources) = outcome else {
            Issue.record("expected suppression, got \(outcome)")
            return
        }
        #expect(resources == SupportResource.bundled)
        #expect(await provider.invocations == 0, "the model must never see crisis text")
    }

    @Test("clear text flows through to a validated reflection")
    func clearTextYieldsReflection() async {
        // Arrange
        let pipeline = ReflectionPipeline(provider: CountingProvider())

        // Act
        let outcome = await pipeline.reflect(on: "Slow morning. Coffee on the balcony before anyone woke up.")

        // Assert
        #expect(outcome == .reflection(ReflectionPrompt(questions: ["What stayed with you?"], themes: ["evening"])))
    }

    @Test("provider output containing regulated vocabulary is rejected, never shown")
    func bannedOutputRejected() async {
        // Arrange
        let tainted = ReflectionPrompt(questions: ["Have you considered therapy for this?"], themes: ["habits"])
        let pipeline = ReflectionPipeline(provider: CountingProvider(result: tainted))

        // Act
        let outcome = await pipeline.reflect(on: "Plain day, nothing much.")

        // Assert
        #expect(outcome == .unavailable)
    }

    @Test("schema violations degrade to unavailable")
    func schemaViolationsRejected() {
        // Arrange / Act / Assert
        #expect(!ReflectionPipeline.validate(ReflectionPrompt(questions: [], themes: [])))
        #expect(!ReflectionPipeline.validate(ReflectionPrompt(questions: ["a?", "b?", "c?"], themes: [])))
        #expect(!ReflectionPipeline.validate(ReflectionPrompt(questions: ["ok?"], themes: ["a", "b", "c", "d"])))
        #expect(!ReflectionPipeline.validate(ReflectionPrompt(questions: ["   "], themes: [])))
        #expect(ReflectionPipeline.validate(ReflectionPrompt(questions: ["ok?"], themes: ["a", "b", "c"])))
    }

    @Test("a throwing provider degrades to unavailable, never raw text")
    func throwingProviderDegrades() async {
        // Arrange
        let pipeline = ReflectionPipeline(provider: ThrowingProvider())

        // Act
        let outcome = await pipeline.reflect(on: "Plain day.")

        // Assert
        #expect(outcome == .unavailable)
    }

    @Test("model-optional journaling: unavailable provider is a quiet no-reflection state")
    func unavailableProviderDegrades() async {
        // Arrange
        let pipeline = ReflectionPipeline(provider: UnavailableProvider())

        // Act
        let outcome = await pipeline.reflect(on: "Plain day.")

        // Assert
        #expect(outcome == .unavailable)
    }
}
