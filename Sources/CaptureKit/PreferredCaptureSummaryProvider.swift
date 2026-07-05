import Foundation

/// Prefers the on-device model, falling back to the deterministic provider when
/// the model is unavailable (e.g. an iOS 26 device without Apple Intelligence, or
/// a generation that throws). It is therefore always available, so the spoken
/// loop engages whenever the user has opted in — on any device, not only
/// Apple-Intelligence-capable ones.
///
/// Mirrors the per-run fallback the InsightKit indexer uses: try the rich model,
/// quietly drop to the deterministic floor rather than going silent.
public struct PreferredCaptureSummaryProvider: CaptureSummaryProviding {
    private let primary: any CaptureSummaryProviding
    private let fallback: any CaptureSummaryProviding

    public init(primary: any CaptureSummaryProviding, fallback: any CaptureSummaryProviding) {
        self.primary = primary
        self.fallback = fallback
    }

    public func availability() async -> CaptureSummaryAvailability {
        // The fallback always works, so the pair always can.
        .available
    }

    public func summary(for entryText: String) async throws -> String {
        if case .available = await primary.availability(),
           let text = try? await primary.summary(for: entryText)
        {
            return text
        }
        return try await fallback.summary(for: entryText)
    }

    public func clarification(for entryText: String) async throws -> String {
        if case .available = await primary.availability(),
           let text = try? await primary.clarification(for: entryText)
        {
            return text
        }
        return try await fallback.clarification(for: entryText)
    }
}
