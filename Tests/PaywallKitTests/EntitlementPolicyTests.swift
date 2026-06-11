import Foundation
@testable import PaywallKit
import Testing

private let calendar = Calendar(identifier: .gregorian)
private let trialStart = Date(timeIntervalSince1970: 1_750_000_000)

private func daysLater(_ days: Int) -> Date {
    calendar.date(byAdding: .day, value: days, to: trialStart)!
}

@Suite("EntitlementPolicy — trial math and the never-paywalled rules")
struct EntitlementPolicyTests {
    @Test("day zero is a full trial")
    func dayZeroTrial() {
        // Act
        let state = EntitlementPolicy.state(trialStartedAt: trialStart, now: trialStart)

        // Assert
        #expect(state == .trial(daysRemaining: 7))
    }

    @Test("day six is the last trial day, day seven expires")
    func trialBoundary() {
        #expect(EntitlementPolicy.state(trialStartedAt: trialStart, now: daysLater(6)) == .trial(daysRemaining: 1))
        #expect(EntitlementPolicy.state(trialStartedAt: trialStart, now: daysLater(7)) == .expired)
        #expect(EntitlementPolicy.state(trialStartedAt: trialStart, now: daysLater(40)) == .expired)
    }

    @Test("subscription and lifetime override the trial clock")
    func purchasesOverride() {
        #expect(
            EntitlementPolicy.state(trialStartedAt: trialStart, now: daysLater(30), hasActiveSubscription: true) == .active
        )
        #expect(
            EntitlementPolicy.state(trialStartedAt: trialStart, now: daysLater(400), hasLifetime: true) == .lifetime
        )
    }

    @Test("capture locks when expired, stays open otherwise")
    func captureGating() {
        #expect(EntitlementPolicy.isCaptureAllowed(.trial(daysRemaining: 2)))
        #expect(EntitlementPolicy.isCaptureAllowed(.active))
        #expect(EntitlementPolicy.isCaptureAllowed(.lifetime))
        #expect(!EntitlementPolicy.isCaptureAllowed(.expired))
    }

    @Test("invariant #8: reading and export are allowed in every state, including expired")
    func readingAndExportNeverPaywalled() {
        let states: [EntitlementState] = [.trial(daysRemaining: 1), .active, .lifetime, .expired]
        for state in states {
            #expect(EntitlementPolicy.isReadingAllowed(state), "reading must stay free in \(state)")
            #expect(EntitlementPolicy.isExportAllowed(state), "export must stay free in \(state)")
        }
    }
}
