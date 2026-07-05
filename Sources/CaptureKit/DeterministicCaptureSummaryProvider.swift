import Foundation
import JournalStore

/// The always-available fallback — no model required. The summary reuses the same
/// deterministic first-sentence/truncation as `EntrySummary.make` (so the recap
/// is literally the person's own words), and the clarification is one fixed open
/// prompt. Lets the confirm loop run everywhere, including devices without Apple
/// Intelligence, keeping voice an enhancement rather than a requirement.
///
/// The clarification string is injected so the app can pass a localized prompt;
/// the English default serves tests and previews.
public struct DeterministicCaptureSummaryProvider: CaptureSummaryProviding {
    private let clarificationQuestion: String

    public init(clarificationQuestion: String = "What else feels worth saying about this?") {
        self.clarificationQuestion = clarificationQuestion
    }

    public func availability() async -> CaptureSummaryAvailability {
        .available
    }

    public func summary(for entryText: String) async throws -> String {
        EntrySummary.make(from: entryText)
    }

    public func clarification(for entryText: String) async throws -> String {
        clarificationQuestion
    }
}
