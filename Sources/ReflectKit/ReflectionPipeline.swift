import Foundation
import SafetyKit

public enum ReflectionOutcome: Sendable, Equatable {
    /// The gate matched: static resources only, the model was never invoked.
    case suppressed(resources: [SupportResource])
    case reflection(ReflectionPrompt)
    /// Model missing, output invalid, or generation failed — surfaces show a quiet
    /// "no reflection" state. Raw model text never reaches the user.
    case unavailable
}

/// The only way Inward asks a model anything: deterministic gate first, schema
/// and lexicon validation after. Product invariants #5 (deterministic crisis
/// handling) and #1 (no regulated vocabulary) live here as code.
public struct ReflectionPipeline: Sendable {
    public static let maxQuestions = 2
    public static let maxThemes = 3

    private let gate: CrisisGate
    private let provider: any ReflectionProviding

    public init(gate: CrisisGate = CrisisGate(), provider: any ReflectionProviding) {
        self.gate = gate
        self.provider = provider
    }

    public func reflect(on entryText: String) async -> ReflectionOutcome {
        if case let .matched(_, resources) = gate.evaluate(entryText) {
            return .suppressed(resources: resources)
        }

        guard case .available = await provider.availability() else {
            return .unavailable
        }

        do {
            let prompt = try await provider.reflection(for: entryText)
            return Self.validate(prompt) ? .reflection(prompt) : .unavailable
        } catch {
            return .unavailable
        }
    }

    /// Schema bounds plus the banned-terms scan over every generated string.
    static func validate(_ prompt: ReflectionPrompt) -> Bool {
        guard (1 ... maxQuestions).contains(prompt.questions.count),
              prompt.themes.count <= maxThemes
        else { return false }

        let allStrings = prompt.questions + prompt.themes
        guard allStrings.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return false
        }
        return allStrings.allSatisfy { BannedTerms.violations(in: $0).isEmpty }
    }
}
