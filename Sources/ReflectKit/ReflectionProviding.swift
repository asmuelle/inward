import Foundation

/// What the on-device model returns after an entry: one or two open questions
/// and up to three quiet theme words. Nothing else, ever.
public struct ReflectionPrompt: Sendable, Equatable, Codable {
    public let questions: [String]
    public let themes: [String]

    public init(questions: [String], themes: [String]) {
        self.questions = questions
        self.themes = themes
    }
}

public enum ReflectionAvailability: Sendable, Equatable {
    case available
    case unavailable(reason: String)
}

public enum ReflectionError: Error, Equatable {
    case modelUnavailable
    case generationFailed(String)
}

/// Boundary for on-device generation. The shipped implementation wraps Apple's
/// FoundationModels; tests use the deterministic mock. No cloud implementation
/// of this protocol may ever exist (product invariant #3).
public protocol ReflectionProviding: Sendable {
    func availability() async -> ReflectionAvailability
    func reflection(for entryText: String) async throws -> ReflectionPrompt
}
