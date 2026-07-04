import Foundation

/// Local app preferences (UserDefaults). These are device-only settings flags,
/// not journal content and not user data — the "Data Not Collected" promise is
/// about the journal, which stays encrypted on disk and never leaves the phone.
enum Prefs {
    static let hasOnboarded = "inward.hasOnboarded"
    static let lockEnabled = "inward.biometricLockEnabled"
    static let trialStartedAt = "inward.trialStartedAt"
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

    /// The trial start, seeded to now on first launch. Local only — never sent
    /// anywhere; entitlement is otherwise derived from StoreKit ownership.
    static func trialStart(now: Date = Date(), defaults: UserDefaults = .standard) -> Date {
        let stored = defaults.double(forKey: trialStartedAt)
        if stored > 0 { return Date(timeIntervalSince1970: stored) }
        defaults.set(now.timeIntervalSince1970, forKey: trialStartedAt)
        return now
    }
}
