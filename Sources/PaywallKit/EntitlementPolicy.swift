import Foundation

public enum EntitlementState: Sendable, Equatable {
    case trial(daysRemaining: Int)
    case active
    case lifetime
    case expired
}

/// Pure paywall arithmetic — StoreKit wiring arrives with M3, but the rules that
/// protect users are testable now: reading and export are never paywalled.
public enum EntitlementPolicy {
    public static let trialLengthDays = 7

    public static func state(
        trialStartedAt: Date,
        now: Date,
        hasActiveSubscription: Bool = false,
        hasLifetime: Bool = false,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> EntitlementState {
        if hasLifetime { return .lifetime }
        if hasActiveSubscription { return .active }

        let elapsed = calendar.dateComponents([.day], from: trialStartedAt, to: now).day ?? Int.max
        let remaining = trialLengthDays - elapsed
        return remaining > 0 ? .trial(daysRemaining: remaining) : .expired
    }

    /// New captures lock when the trial lapses.
    public static func isCaptureAllowed(_ state: EntitlementState) -> Bool {
        switch state {
        case .trial, .active, .lifetime: true
        case .expired: false
        }
    }

    /// Product invariant #8: users always own their words.
    public static func isReadingAllowed(_: EntitlementState) -> Bool {
        true
    }

    /// Product invariant #8: export is never paywalled either.
    public static func isExportAllowed(_: EntitlementState) -> Bool {
        true
    }
}
