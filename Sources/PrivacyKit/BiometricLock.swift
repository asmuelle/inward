import Foundation

/// What kind of credential can guard the journal on this device.
public enum BiometryKind: String, Sendable, Equatable, Codable {
    case faceID
    case touchID
    case opticID
    /// No biometric enrolled, but a device passcode exists — still a real lock.
    case passcodeOnly
}

public enum BiometricAvailability: Sendable, Equatable {
    case available(BiometryKind)
    /// No credential exists at all (no biometric, no passcode). A lock here would
    /// guard nothing and could trap the user, so the controller stays unlocked.
    case unavailable(reason: String)
}

/// Outcome of one authentication attempt. `unavailable` means the device lost the
/// ability to authenticate mid-session; `canceled` is the user dismissing the prompt.
public enum AuthOutcome: Sendable, Equatable {
    case success
    case failed
    case canceled
    case unavailable
}

/// Boundary for device-owner authentication. The shipped implementation wraps
/// LocalAuthentication (`.deviceOwnerAuthentication` — biometrics OR passcode, so
/// the user can never be locked out of their own words); tests inject a mock.
public protocol BiometricAuthenticating: Sendable {
    func availability() -> BiometricAvailability
    func authenticate(reason: String) async -> AuthOutcome
}

/// Deterministic authenticator for tests and previews: fixed availability and a
/// scripted outcome. No hardware, no prompts.
public struct MockBiometricAuthenticator: BiometricAuthenticating {
    private let availabilityValue: BiometricAvailability
    private let outcome: AuthOutcome

    public init(
        availability: BiometricAvailability = .available(.faceID),
        outcome: AuthOutcome = .success
    ) {
        availabilityValue = availability
        self.outcome = outcome
    }

    public func availability() -> BiometricAvailability { availabilityValue }
    public func authenticate(reason _: String) async -> AuthOutcome { outcome }
}

public enum LockState: Sendable, Equatable {
    case locked
    case unlocked
}

/// The privacy lock's state machine, isolated from any platform API so the policy
/// is fully testable. The lock is *active* only when the user enabled it AND the
/// device can actually authenticate — enabling a lock on a device with no
/// credential would guard nothing and risk trapping the user, so it stays open.
public actor BiometricLockController {
    public private(set) var state: LockState
    private let authenticator: any BiometricAuthenticating
    private let lockActive: Bool

    public init(authenticator: any BiometricAuthenticating, userEnabled: Bool) {
        self.authenticator = authenticator
        let deviceCanAuthenticate: Bool
        if case .available = authenticator.availability() {
            deviceCanAuthenticate = true
        } else {
            deviceCanAuthenticate = false
        }
        lockActive = userEnabled && deviceCanAuthenticate
        state = lockActive ? .locked : .unlocked
    }

    /// Whether a credential prompt will actually gate this session.
    public var isLockActive: Bool { lockActive }

    /// Attempt to unlock. Only a successful authentication opens the lock; a
    /// failure, cancellation, or transient unavailability leaves it closed so the
    /// user can retry. A no-op when the lock is inactive or already open.
    @discardableResult
    public func unlock(reason: String) async -> LockState {
        guard lockActive, state == .locked else { return state }
        if case .success = await authenticator.authenticate(reason: reason) {
            state = .unlocked
        }
        return state
    }

    /// Re-lock — call when the app leaves the foreground. No-op if inactive.
    public func lock() {
        if lockActive { state = .locked }
    }
}
