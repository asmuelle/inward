import DesignSystem
import PrivacyKit
import SwiftUI

/// Bridges the actor-isolated, fully-tested `BiometricLockController` to SwiftUI.
/// It owns no policy of its own — each decision builds a controller from the live
/// "lock enabled" preference, so toggling the setting is always respected.
@MainActor
@Observable
final class LockGateModel {
    private(set) var state: LockState = .unlocked

    private let authenticator: any BiometricAuthenticating
    private let isEnabled: @Sendable () -> Bool

    init(authenticator: any BiometricAuthenticating, isEnabled: @escaping @Sendable () -> Bool) {
        self.authenticator = authenticator
        self.isEnabled = isEnabled
    }

    /// Close the gate on launch and when returning to the foreground. Locks only
    /// when the user enabled it and the device can actually authenticate.
    func engage() async {
        let controller = BiometricLockController(authenticator: authenticator, userEnabled: isEnabled())
        state = await controller.state
    }

    /// Prompt for device-owner authentication; the gate opens only on success.
    func attemptUnlock() async {
        let controller = BiometricLockController(authenticator: authenticator, userEnabled: isEnabled())
        state = await controller.unlock(reason: Copy.unlockReason)
    }
}

/// The lock screen: a warm lamplight cover that fully hides the journal until the
/// owner authenticates. Opaque by design — the timeline must not show through.
struct LockView: View {
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color.inwardLamplight.ignoresSafeArea()
            VStack(spacing: Lamplight.Spacing.block) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Color.inwardAmberText)
                Text(Copy.lockTitle)
                    .font(.lamplight(.journalTitle))
                    .foregroundStyle(Color.inwardAmberText)
                Text(Copy.lockSubtitle)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardAmberText.opacity(0.75))
                Button(action: onUnlock) {
                    Text(Copy.lockUnlock)
                        .font(.lamplight(.chrome))
                        .foregroundStyle(Color.inwardPaper)
                        .padding(.horizontal, Lamplight.Spacing.section)
                        .padding(.vertical, Lamplight.Spacing.element)
                        .background(Capsule().fill(Color.inwardClay))
                }
                .buttonStyle(.plain)
                .padding(.top, Lamplight.Spacing.element)
            }
        }
    }
}
