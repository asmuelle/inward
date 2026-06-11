import Foundation

// compliance-lexicon-definition — this file is the single allowed home of the
// regulated vocabulary (see AGENTS.md invariant #1) and is exempted from the
// source scan in ComplianceTests. Do not copy these words anywhere else.

/// The lexicon Inward must never use in user-facing language. The Illinois WOPR
/// Act regulates the service, not the server — on-device inference is no shield,
/// so the words simply never appear. Enforced in CI by ComplianceTests.
public enum BannedTerms {
    public static let lexicon: [String] = [
        "therapy",
        "therapist",
        "therapeutic",
        "cbt",
        "cognitive behavioral",
        "cognitive behavioural",
        "cognitive distortion",
        "diagnose",
        "diagnosis",
        "treatment",
        "counseling",
        "counselling",
        "psychotherapy",
        "clinical",
        "mental illness",
    ]

    public struct Violation: Sendable, Equatable {
        public let term: String

        public init(term: String) {
            self.term = term
        }
    }

    /// Whole-word scan over normalized text. Empty result means the text is clean.
    public static func violations(in text: String) -> [Violation] {
        let normalized = TextNormalizer.normalize(text)
        guard !normalized.isEmpty else { return [] }
        return lexicon
            .filter { TextNormalizer.containsPhrase($0, in: normalized) }
            .map(Violation.init(term:))
    }
}
