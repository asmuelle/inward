import Foundation
import ReflectKit

/// Decides whether to ask for an App Store rating — the one growth lever an app
/// with no accounts, no analytics, and no network can actually pull.
///
/// The rules are deliberately conservative, and they live here rather than in
/// the view so they can be tested without StoreKit:
///
/// 1. **Once, ever.** A second ask is the system's to schedule, not ours.
/// 2. **Only after a week that produced something** — synthesized observations
///    or deterministic recurring themes. Never on an empty or unavailable week.
/// 3. **Never in the crisis-suppressed state.** Asking someone who just wrote
///    their darkest entry to rate the app is indefensible, and the state is
///    reachable, so it is excluded explicitly rather than by assumption.
enum ReviewPrompt {
    /// Seconds to let the review be read before the system sheet appears. The
    /// ask should feel like it followed the value, not interrupted it.
    static let settleDelay: Double = 1.5

    static func shouldAsk(for outcome: WeeklyReviewOutcome?, alreadyAsked: Bool) -> Bool {
        guard !alreadyAsked else { return false }
        return switch outcome {
        case .synthesized, .themesOnly: true
        case .suppressed, .unavailable, .none: false
        }
    }
}
