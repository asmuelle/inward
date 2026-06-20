import Foundation
@testable import PrivacyKit
import Testing

/// Counts authentication attempts so tests can prove the prompt is skipped when
/// the lock is inactive or already open.
private actor CountingAuthenticator: BiometricAuthenticating {
    private(set) var attempts = 0
    private let availabilityValue: BiometricAvailability
    private let outcome: AuthOutcome

    init(availability: BiometricAvailability = .available(.faceID), outcome: AuthOutcome = .success) {
        availabilityValue = availability
        self.outcome = outcome
    }

    nonisolated func availability() -> BiometricAvailability { availabilityValue }

    func authenticate(reason _: String) async -> AuthOutcome {
        attempts += 1
        return outcome
    }
}

@Suite("BiometricLockController — the privacy gate's state machine")
struct BiometricLockControllerTests {
    @Test("enabled on a capable device starts locked")
    func enabledStartsLocked() async {
        let controller = BiometricLockController(authenticator: MockBiometricAuthenticator(), userEnabled: true)

        #expect(await controller.state == .locked)
        #expect(await controller.isLockActive)
    }

    @Test("disabled by the user starts unlocked and never prompts")
    func disabledStartsUnlocked() async {
        let auth = CountingAuthenticator()
        let controller = BiometricLockController(authenticator: auth, userEnabled: false)

        let state = await controller.unlock(reason: "Open your journal")

        #expect(state == .unlocked)
        #expect(await controller.isLockActive == false)
        #expect(await auth.attempts == 0, "an inactive lock must never prompt")
    }

    @Test("enabled but no device credential stays unlocked — a lock would trap the owner")
    func noCredentialStaysUnlocked() async {
        let auth = CountingAuthenticator(availability: .unavailable(reason: "no passcode set"))
        let controller = BiometricLockController(authenticator: auth, userEnabled: true)

        #expect(await controller.state == .unlocked)
        #expect(await controller.isLockActive == false)
        #expect(await auth.attempts == 0)
    }

    @Test("a successful authentication opens the lock")
    func successUnlocks() async {
        let controller = BiometricLockController(
            authenticator: MockBiometricAuthenticator(outcome: .success),
            userEnabled: true
        )

        let state = await controller.unlock(reason: "Open your journal")

        #expect(state == .unlocked)
    }

    @Test("failure, cancellation, and transient unavailability all keep it locked for retry", arguments: [
        AuthOutcome.failed, .canceled, .unavailable,
    ])
    func nonSuccessStaysLocked(outcome: AuthOutcome) async {
        let controller = BiometricLockController(
            authenticator: MockBiometricAuthenticator(outcome: outcome),
            userEnabled: true
        )

        let state = await controller.unlock(reason: "Open your journal")

        #expect(state == .locked)
    }

    @Test("once unlocked, unlock is a no-op and does not prompt again")
    func unlockIsIdempotent() async {
        let auth = CountingAuthenticator(outcome: .success)
        let controller = BiometricLockController(authenticator: auth, userEnabled: true)

        _ = await controller.unlock(reason: "Open your journal")
        _ = await controller.unlock(reason: "Open your journal")

        #expect(await controller.state == .unlocked)
        #expect(await auth.attempts == 1, "no second prompt once already open")
    }

    @Test("leaving the foreground re-locks an active lock")
    func backgroundRelocks() async {
        let controller = BiometricLockController(
            authenticator: MockBiometricAuthenticator(outcome: .success),
            userEnabled: true
        )
        _ = await controller.unlock(reason: "Open your journal")
        #expect(await controller.state == .unlocked)

        await controller.lock()

        #expect(await controller.state == .locked)
    }
}
