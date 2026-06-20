import Foundation

/// Deterministic weekly-review provider for tests and previews. It builds one
/// observation per recurring theme found in the week and cites exactly the entries
/// that theme came from — so its output is grounded by construction. No model,
/// no randomness: same week in, same review out.
public struct MockWeeklyReviewProvider: WeeklyReviewProviding {
    public init() {}

    public func availability() async -> ReflectionAvailability {
        .available
    }

    public func review(for context: WeekContext) async throws -> WeeklyReviewDraft {
        let themes = WeeklyReviewPipeline.recurringThemes(in: context)
        let observations = themes.map { theme in
            WeeklyObservation(
                theme: theme.theme,
                note: "“\(theme.theme)” came back across \(theme.count) of your entries this week.",
                citedEntryIds: theme.entryIds
            )
        }
        return WeeklyReviewDraft(observations: observations)
    }
}
