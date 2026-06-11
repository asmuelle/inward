import Foundation

/// Deterministic reflection provider for tests and previews. Same input, same
/// output, every run — question choice uses a stable string hash, themes are the
/// longest distinct words. No randomness, no model.
public struct MockReflectionProvider: ReflectionProviding {
    private static let questionBank: [[String]] = [
        ["What part of that still has your attention?"],
        ["If you read this back in a month, what would you want to remember?", "What felt heaviest as you said it?"],
        ["What would you tell a friend who said the same thing?"],
        ["Where in your day did that feeling first show up?", "What was different the last time this came up?"],
    ]

    public init() {}

    public func availability() async -> ReflectionAvailability {
        .available
    }

    public func reflection(for entryText: String) async throws -> ReflectionPrompt {
        let normalized = entryText.lowercased()
        let bank = Self.questionBank
        let index = Int(Self.stableHash(normalized) % UInt64(bank.count))
        return ReflectionPrompt(questions: bank[index], themes: Self.themes(from: normalized))
    }

    /// djb2 — Swift's `hashValue` is seeded per-process, so determinism needs its own hash.
    static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in text.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return hash
    }

    static func themes(from text: String) -> [String] {
        let words = text
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count > 4 }
        let distinct = Array(Set(words))
        let ranked = distinct.sorted { lhs, rhs in
            lhs.count != rhs.count ? lhs.count > rhs.count : lhs < rhs
        }
        return Array(ranked.prefix(3))
    }
}
