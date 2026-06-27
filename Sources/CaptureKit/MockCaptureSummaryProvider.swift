import Foundation

/// Deterministic stand-in for the on-device summary model. Returns scripted text
/// (or throws) so the pipeline and the confirm loop are fully exercisable without
/// a model. The app never fabricates a recap — this is tests and previews only.
public struct MockCaptureSummaryProvider: CaptureSummaryProviding {
    private let summaryText: String
    private let questionText: String
    private let reportedAvailability: CaptureSummaryAvailability
    private let shouldThrow: Bool

    public init(
        summary: String = "You talked about the meeting and how it left you.",
        clarification: String = "What part of it stayed with you?",
        availability: CaptureSummaryAvailability = .available,
        shouldThrow: Bool = false
    ) {
        summaryText = summary
        questionText = clarification
        reportedAvailability = availability
        self.shouldThrow = shouldThrow
    }

    public func availability() async -> CaptureSummaryAvailability {
        reportedAvailability
    }

    public func summary(for _: String) async throws -> String {
        if shouldThrow { throw CaptureSummaryError.generationFailed("mock") }
        return summaryText
    }

    public func clarification(for _: String) async throws -> String {
        if shouldThrow { throw CaptureSummaryError.generationFailed("mock") }
        return questionText
    }
}
