import Foundation

public enum SpeechSynthesisAvailability: Sendable, Equatable {
    case available
    case unavailable(reason: String)

    public var isAvailable: Bool {
        self == .available
    }
}

/// Boundary for on-device text-to-speech. The real engine wraps
/// `AVSpeechSynthesizer`; tests and previews use the deterministic mock. Like
/// transcription, this is an enhancement, never a requirement — the confirm loop
/// degrades to the silent read-it-back editor when speech output is unavailable
/// (product invariant #9). Speaking stays fully on-device, so it keeps the
/// airplane-mode promise (invariant #2).
public protocol SpeechSynthesisEngine: Sendable {
    /// Whether spoken output can be produced (at least one installed voice).
    func availability() async -> SpeechSynthesisAvailability

    /// Speaks `text` aloud, resolving once the utterance has finished, been
    /// stopped, or failed. Never throws — a failed utterance simply returns, so
    /// the caller can fall through to the on-screen summary unconditionally.
    /// `locale` is a `Locale.identifier` (e.g. `en_US`); the engine maps it to a
    /// matching voice and falls back to the system default when none exists.
    func speak(_ text: String, locale: String) async

    /// Stops any in-flight utterance immediately.
    func stop() async
}
