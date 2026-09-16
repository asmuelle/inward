import Foundation

/// Local app preferences (UserDefaults). These are device-only settings flags,
/// not journal content and not user data — the "Data Not Collected" promise is
/// about the journal, which stays encrypted on disk and never leaves the phone.
enum Prefs {
    static let hasOnboarded = "inward.hasOnboarded"
    static let lockEnabled = "inward.biometricLockEnabled"
    /// Opt-in: after a recording, speak a short recap and ask to keep it. Off by
    /// default so the calm, instant capture stays the norm unless chosen.
    static let spokenSummaryEnabled = "inward.spokenSummaryEnabled"
    /// Opt-in weekly review reminder: one local notification a week, scheduled
    /// by the user (DESIGN.md flow #3). Day is `Calendar` weekday (1 = Sunday);
    /// time is minutes since local midnight.
    static let weeklyReminderEnabled = "inward.weeklyReminderEnabled"
    static let weeklyReminderWeekday = "inward.weeklyReminderWeekday"
    static let weeklyReminderMinutes = "inward.weeklyReminderMinutes"
    /// Entry ids the user asked never to resurface as an "on this day" echo.
    /// Ids only — no journal content lives in preferences.
    static let echoDismissed = "inward.echoDismissedEntryIDs"
    static let hasShownFirstLook = "inward.hasShownFirstLook"
    /// Set once the App Store rating sheet has been offered, so it never is
    /// again — see `ReviewPrompt` for the rules around when it may appear.
    static let hasAskedForReview = "inward.hasAskedForReview"
}
