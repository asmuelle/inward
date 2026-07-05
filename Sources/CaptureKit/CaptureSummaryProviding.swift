import Foundation

public enum CaptureSummaryAvailability: Sendable, Equatable {
    case available
    case unavailable(reason: String)
}

public enum CaptureSummaryError: Error, Equatable {
    case modelUnavailable
    case generationFailed(String)
}

/// Boundary for on-device generation in the capture confirm loop. The shipped
/// implementation wraps Apple's on-device model; the deterministic provider is
/// the offline-everywhere fallback; tests use the mock. Mirrors
/// `ReflectionProviding`: the model is only ever reached behind the crisis gate
/// in `CaptureSummaryPipeline`, and every string it returns is validated before
/// it is spoken or shown (product invariants #1 no regulated vocabulary, #3
/// no unbounded model output, #5 deterministic crisis handling).
///
/// Both calls take and return plain text — the provider never sees an `Entry`.
public protocol CaptureSummaryProviding: Sendable {
    func availability() async -> CaptureSummaryAvailability

    /// One or two short sentences that neutrally recap the person's own words,
    /// for reading back before they decide to keep the note.
    func summary(for entryText: String) async throws -> String

    /// One open question inviting the person to expand on what they just
    /// recorded — used when they choose "Add more" instead of keeping.
    func clarification(for entryText: String) async throws -> String
}
