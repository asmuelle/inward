import Foundation

/// Deterministic stand-in for `AVSpeechSynthesizer`: records what it was asked to
/// speak and returns immediately instead of producing audio. Used by tests and
/// previews so the confirm loop's state machine is fully exercisable without a
/// device — the real audio handoff is validated separately on hardware.
public actor MockSpeechSynthesisEngine: SpeechSynthesisEngine {
    /// Test inspection: the non-empty texts passed to `speak`, in order, and the
    /// locale each was spoken with (parallel arrays for easy assertion).
    public private(set) var spokenUtterances: [String] = []
    public private(set) var spokenLocales: [String] = []
    public private(set) var didStop = false

    private let reportedAvailability: SpeechSynthesisAvailability

    public init(availability: SpeechSynthesisAvailability = .available) {
        reportedAvailability = availability
    }

    public func availability() async -> SpeechSynthesisAvailability {
        reportedAvailability
    }

    public func speak(_ text: String, locale: String) async {
        // Mirror the real engine: empty/whitespace text produces no utterance, so
        // tests of the loop see the same skip behavior as production.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        spokenUtterances.append(trimmed)
        spokenLocales.append(locale)
    }

    public func stop() async {
        didStop = true
    }
}
