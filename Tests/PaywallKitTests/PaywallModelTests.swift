import Foundation
@testable import PaywallKit
import Testing

private struct FailingGateway: PurchaseGateway {
    enum Failure: Error { case unavailable }

    let failProducts: Bool

    func availableProducts() async throws -> [PaywallProduct] {
        if failProducts { throw Failure.unavailable }
        return PaywallProduct.samples
    }

    func purchase(_: String) async throws -> PurchaseResult {
        throw Failure.unavailable
    }

    func restore() async throws {
        throw Failure.unavailable
    }

    func ownedProductIDs() async -> Set<String> {
        []
    }

    func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

@MainActor
@Suite("PaywallModel — StoreKit-only entitlement and recoverable failures")
struct PaywallModelTests {
    @Test("products load annual-first and no local trial unlocks the app")
    func productsLoad() async {
        let model = PaywallModel(gateway: MockPurchaseGateway())

        await model.refresh()

        #expect(model.entitlement == .expired)
        #expect(model.loadState == .loaded)
        #expect(model.products.map(\.kind) == [.annual, .monthly, .lifetime])
    }

    @Test("a product loading failure is visible and retryable")
    func productFailureIsVisible() async {
        let model = PaywallModel(gateway: FailingGateway(failProducts: true))

        await model.refresh()

        guard case .failed = model.loadState else {
            Issue.record("expected a failed load state")
            return
        }
        #expect(model.products.isEmpty)
        #expect(model.lastErrorMessage != nil)
    }

    @Test("purchase errors are failures, never disguised as pending")
    func purchaseFailureIsVisible() async {
        let model = PaywallModel(gateway: FailingGateway(failProducts: false))

        let result = await model.purchase(InwardProduct.annual.rawValue)

        guard case .failed = result else {
            Issue.record("expected a failed purchase result")
            return
        }
        #expect(model.lastErrorMessage != nil)
    }

    @Test("buying annual unlocks the app")
    func purchaseAnnualUnlocks() async {
        let model = PaywallModel(gateway: MockPurchaseGateway())

        let result = await model.purchase(InwardProduct.annual.rawValue)

        #expect(result == .success)
        #expect(model.entitlement == .active)
        #expect(!model.isInsightLocked)
    }

    @Test("restore failure is visible")
    func restoreFailureIsVisible() async {
        let model = PaywallModel(gateway: FailingGateway(failProducts: false))

        await model.restore()

        #expect(model.lastErrorMessage != nil)
    }

    @Test("subscription samples expose billing and eligible free-trial terms")
    func productTermsAreExplicit() throws {
        let annual = try #require(PaywallProduct.samples.first { $0.kind == .annual })

        #expect(annual.billingPeriod == BillingPeriod(value: 1, unit: .year))
        #expect(annual.introductoryOffer == IntroductoryOffer(period: BillingPeriod(value: 1, unit: .week)))
    }
}
