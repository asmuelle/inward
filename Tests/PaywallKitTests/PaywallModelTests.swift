import Foundation
@testable import PaywallKit
import Testing

private let trialStart = Date(timeIntervalSince1970: 1_750_000_000)
private let calendar = Calendar(identifier: .gregorian)

private func daysLater(_ days: Int) -> Date {
    calendar.date(byAdding: .day, value: days, to: trialStart)!
}

@MainActor
@Suite("PaywallModel — the trial → purchase → restore loop")
struct PaywallModelTests {
    private func model(
        gateway: any PurchaseGateway,
        now: Date
    ) -> PaywallModel {
        PaywallModel(gateway: gateway, trialStartedAt: trialStart, now: { now }, calendar: calendar)
    }

    @Test("during the trial the app is unlocked and products load annual-first")
    func trialUnlockedAndProductsLoad() async {
        let model = model(gateway: MockPurchaseGateway(), now: daysLater(2))

        await model.refresh()

        #expect(model.entitlement == .trial(daysRemaining: 5))
        #expect(model.isLocked == false)
        #expect(model.products.map(\.kind) == [.annual, .monthly, .lifetime])
    }

    @Test("after the trial lapses with no purchase, capture is locked")
    func lapsedTrialLocks() async {
        let model = model(gateway: MockPurchaseGateway(), now: daysLater(10))

        await model.refresh()

        #expect(model.entitlement == .expired)
        #expect(model.isLocked)
    }

    @Test("buying the annual subscription unlocks the app")
    func purchaseAnnualUnlocks() async {
        let model = model(gateway: MockPurchaseGateway(), now: daysLater(10))
        await model.refresh()
        #expect(model.isLocked)

        let result = await model.purchase(InwardProduct.annual.rawValue)

        #expect(result == .success)
        #expect(model.entitlement == .active)
        #expect(model.isLocked == false)
    }

    @Test("buying lifetime grants lifetime entitlement")
    func purchaseLifetime() async {
        let model = model(gateway: MockPurchaseGateway(), now: daysLater(10))

        _ = await model.purchase(InwardProduct.lifetime.rawValue)

        #expect(model.entitlement == .lifetime)
    }

    @Test("a cancelled purchase changes nothing")
    func cancelledPurchaseIsNoop() async {
        let model = model(gateway: MockPurchaseGateway(purchaseResult: .userCancelled), now: daysLater(10))
        await model.refresh()

        let result = await model.purchase(InwardProduct.annual.rawValue)

        #expect(result == .userCancelled)
        #expect(model.entitlement == .expired)
        #expect(model.isLocked)
    }

    @Test("restore recovers a previously-owned lifetime purchase")
    func restoreRecoversLifetime() async {
        let gateway = MockPurchaseGateway(restorable: [InwardProduct.lifetime.rawValue])
        let model = model(gateway: gateway, now: daysLater(10))
        await model.refresh()
        #expect(model.isLocked)

        await model.restore()

        #expect(model.entitlement == .lifetime)
        #expect(model.isLocked == false)
    }
}

@Suite("EntitlementPolicy — entitlement from owned product ids")
struct EntitlementFromOwnedTests {
    @Test("lifetime ownership wins even long past the trial")
    func lifetimeWins() {
        let state = EntitlementPolicy.state(
            trialStartedAt: trialStart,
            now: daysLater(400),
            ownedProductIDs: [InwardProduct.lifetime.rawValue]
        )
        #expect(state == .lifetime)
    }

    @Test("an active subscription is active past the trial")
    func subscriptionActive() {
        #expect(
            EntitlementPolicy.state(trialStartedAt: trialStart, now: daysLater(40), ownedProductIDs: [InwardProduct.monthly.rawValue]) == .active
        )
        #expect(
            EntitlementPolicy.state(trialStartedAt: trialStart, now: daysLater(40), ownedProductIDs: [InwardProduct.annual.rawValue]) == .active
        )
    }

    @Test("owning nothing follows the trial clock")
    func nothingOwnedFollowsTrial() {
        #expect(EntitlementPolicy.state(trialStartedAt: trialStart, now: daysLater(1), ownedProductIDs: []) == .trial(daysRemaining: 6))
        #expect(EntitlementPolicy.state(trialStartedAt: trialStart, now: daysLater(8), ownedProductIDs: []) == .expired)
    }
}
