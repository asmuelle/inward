@testable import PaywallKit
import Testing

@Suite("EntitlementPolicy — StoreKit ownership and free-sample rules")
struct EntitlementPolicyTests {
    @Test("no StoreKit ownership is expired; there is no second local trial")
    func noLocalTrial() {
        #expect(EntitlementPolicy.state(ownedProductIDs: []) == .expired)
    }

    @Test("subscription and lifetime ownership unlock paid features")
    func purchasesUnlock() {
        #expect(EntitlementPolicy.state(ownedProductIDs: [InwardProduct.monthly.rawValue]) == .active)
        #expect(EntitlementPolicy.state(ownedProductIDs: [InwardProduct.annual.rawValue]) == .active)
        #expect(EntitlementPolicy.state(ownedProductIDs: [InwardProduct.lifetime.rawValue]) == .lifetime)
    }

    @Test("capture is free in every state — the paid tier is generated insight")
    func captureIsNeverPaywalled() {
        for state in [EntitlementState.active, .lifetime, .expired] {
            #expect(EntitlementPolicy.isCaptureAllowed(state))
        }
        // …and insight is exactly what ownership buys.
        #expect(!EntitlementPolicy.isInsightAllowed(.expired))
        #expect(EntitlementPolicy.isInsightAllowed(.active))
        #expect(EntitlementPolicy.isInsightAllowed(.lifetime))
    }

    @Test("the first look appears once when the third entry is saved")
    func firstLookThreshold() {
        #expect(FreeSamplePolicy.shouldPresentFirstLook(previousCount: 2, currentCount: 3, alreadyShown: false))
        #expect(!FreeSamplePolicy.shouldPresentFirstLook(previousCount: 3, currentCount: 4, alreadyShown: false))
        #expect(!FreeSamplePolicy.shouldPresentFirstLook(previousCount: 2, currentCount: 3, alreadyShown: true))
    }

    @Test("reading and export are allowed in every state")
    func readingAndExportNeverPaywalled() {
        let states: [EntitlementState] = [.active, .lifetime, .expired]
        for state in states {
            #expect(EntitlementPolicy.isReadingAllowed(state))
            #expect(EntitlementPolicy.isExportAllowed(state))
        }
    }
}
