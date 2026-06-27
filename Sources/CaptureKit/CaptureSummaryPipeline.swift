import Foundation
import SafetyKit

/// What the loop should do with a just-recorded note before saving.
public enum CaptureSummaryOutcome: Sendable, Equatable {
    /// The crisis gate matched: no recap is spoken and no keep/clarify upsell is
    /// shown. The loop saves the entry quietly and lets the app's existing safety
    /// surfaces present resources — the model is never invoked.
    case suppressed(resources: [SupportResource])
    case summary(String)
    /// Model missing, output invalid, or generation failed — the loop falls back
    /// to the silent read-it-back editor. Raw model text never reaches the user.
    case unavailable
}

/// The clarification counterpart, returned when the person asks to expand.
public enum CaptureClarificationOutcome: Sendable, Equatable {
    case suppressed(resources: [SupportResource])
    case question(String)
    case unavailable
}

/// The one path through which the capture loop asks a model anything: crisis gate
/// first, schema + lexicon validation after. Identical discipline to
/// `ReflectionPipeline` — deterministic crisis handling and the banned-terms scan
/// live here as code, not as prompt requests the model might ignore.
public struct CaptureSummaryPipeline: Sendable {
    public static let maxSummaryLength = 240
    public static let maxQuestionLength = 160

    private let gate: CrisisGate
    private let provider: any CaptureSummaryProviding

    public init(gate: CrisisGate = CrisisGate(), provider: any CaptureSummaryProviding) {
        self.gate = gate
        self.provider = provider
    }

    public func summarize(_ entryText: String) async -> CaptureSummaryOutcome {
        if case let .matched(_, resources) = gate.evaluate(entryText) {
            return .suppressed(resources: resources)
        }
        guard case .available = await provider.availability() else { return .unavailable }
        do {
            let raw = try await provider.summary(for: entryText)
            guard let clean = Self.validate(raw, maxLength: Self.maxSummaryLength) else { return .unavailable }
            return .summary(clean)
        } catch {
            return .unavailable
        }
    }

    public func clarify(_ entryText: String) async -> CaptureClarificationOutcome {
        if case let .matched(_, resources) = gate.evaluate(entryText) {
            return .suppressed(resources: resources)
        }
        guard case .available = await provider.availability() else { return .unavailable }
        do {
            let raw = try await provider.clarification(for: entryText)
            guard let clean = Self.validate(raw, maxLength: Self.maxQuestionLength) else { return .unavailable }
            return .question(clean)
        } catch {
            return .unavailable
        }
    }

    /// Trims, bounds length, and scans for regulated vocabulary. Returns nil when
    /// the text is empty, over `maxLength`, or contains a banned term — in which
    /// case the pipeline reports `.unavailable` and the raw text is discarded.
    static func validate(_ raw: String, maxLength: Int) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength else { return nil }
        guard BannedTerms.violations(in: trimmed).isEmpty else { return nil }
        return trimmed
    }
}
