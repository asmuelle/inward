@testable import Inward
import ReflectKit
import SafetyKit
import Testing

/// The rating ask has one hard rule that matters more than conversion: it never
/// appears in the crisis-suppressed state. These tests pin that, and the
/// once-ever and earned-it rules alongside it.
@Suite("Review prompt — when the app may ask for a rating")
struct ReviewPromptTests {
    @Test("asks after a week that produced observations")
    func asksAfterSynthesizedWeek() {
        let outcome = WeeklyReviewOutcome.synthesized(
            WeeklyReviewDraft(observations: [])
        )
        #expect(ReviewPrompt.shouldAsk(for: outcome, alreadyAsked: false))
    }

    @Test("asks after a deterministic themes-only week")
    func asksAfterThemesOnlyWeek() {
        #expect(ReviewPrompt.shouldAsk(for: .themesOnly([]), alreadyAsked: false))
    }

    @Test("never asks in the crisis-suppressed state")
    func neverAsksWhenSuppressed() {
        let outcome = WeeklyReviewOutcome.suppressed(resources: SupportResource.bundled)
        #expect(!ReviewPrompt.shouldAsk(for: outcome, alreadyAsked: false))
    }

    @Test("never asks on an empty or unavailable week")
    func neverAsksWithoutValue() {
        #expect(!ReviewPrompt.shouldAsk(for: .unavailable, alreadyAsked: false))
        #expect(!ReviewPrompt.shouldAsk(for: nil, alreadyAsked: false))
    }

    @Test("never asks twice, whatever the week held")
    func neverAsksTwice() {
        #expect(!ReviewPrompt.shouldAsk(for: .themesOnly([]), alreadyAsked: true))
        #expect(!ReviewPrompt.shouldAsk(for: .synthesized(WeeklyReviewDraft(observations: [])), alreadyAsked: true))
    }
}
