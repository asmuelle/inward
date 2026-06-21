import Foundation

public enum InsightAvailability: Sendable, Equatable {
    case available
    case unavailable(reason: String)

    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

public enum InsightError: Error, Equatable {
    case modelUnavailable
    case generationFailed(String)
}

/// Pulls structured insights out of a single entry. Mirrors ReflectKit's
/// provider shape: an availability gate plus the work. Two implementations — a
/// deterministic `NaturalLanguage` floor and an Apple-Intelligence extractor —
/// keep the feature model-optional (invariant #9).
public protocol EntityExtracting: Sendable {
    func availability() async -> InsightAvailability
    func extract(from entry: ExtractableEntry) async throws -> EntryInsights
}
