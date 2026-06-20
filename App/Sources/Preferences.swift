import Foundation

/// Local app preferences (UserDefaults). These are device-only settings flags,
/// not journal content and not user data — the "Data Not Collected" promise is
/// about the journal, which stays encrypted on disk and never leaves the phone.
enum Prefs {
    static let hasOnboarded = "inward.hasOnboarded"
    static let lockEnabled = "inward.biometricLockEnabled"
}
