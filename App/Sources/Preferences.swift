import Foundation

/// Local app preferences (UserDefaults). These are device-only settings flags,
/// not journal content and not user data — the "Data Not Collected" promise is
/// about the journal, which stays encrypted on disk and never leaves the phone.
enum Prefs {
    static let hasOnboarded = "inward.hasOnboarded"
    static let lockEnabled = "inward.biometricLockEnabled"
    static let trialStartedAt = "inward.trialStartedAt"

    /// The trial start, seeded to now on first launch. Local only — never sent
    /// anywhere; entitlement is otherwise derived from StoreKit ownership.
    static func trialStart(now: Date = Date(), defaults: UserDefaults = .standard) -> Date {
        let stored = defaults.double(forKey: trialStartedAt)
        if stored > 0 { return Date(timeIntervalSince1970: stored) }
        defaults.set(now.timeIntervalSince1970, forKey: trialStartedAt)
        return now
    }
}
