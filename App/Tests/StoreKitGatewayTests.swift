import Foundation
import PaywallKit
import StoreKit
import StoreKitTest
import Testing

/// StoreKitTest coverage (DESIGN M3 acceptance): the real StoreKit gateway against
/// the bundled .storekit config. Serialized because the test session is process-wide.
@Suite("StoreKitPurchaseGateway — against the bundled StoreKit config", .serialized)
struct StoreKitGatewayTests {
    private func session() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Inward")
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    @Test("the three Inward products load with their kinds")
    func loadsProducts() async throws {
        _ = try session()
        let gateway = StoreKitPurchaseGateway()

        let products = try await gateway.availableProducts()

        #expect(Set(products.map(\.id)) == Set(InwardProduct.allCases.map(\.rawValue)))
        #expect(products.contains { $0.kind == .annual })
        #expect(products.contains { $0.kind == .lifetime })
    }

    @Test("buying lifetime is recorded as an owned product")
    func purchaseGrantsOwnership() async throws {
        let testSession = try session()
        defer { testSession.clearTransactions() }
        let gateway = StoreKitPurchaseGateway()

        let result = try await gateway.purchase(InwardProduct.lifetime.rawValue)

        #expect(result == .success)
        let owned = await gateway.ownedProductIDs()
        #expect(owned.contains(InwardProduct.lifetime.rawValue))
    }

    @Test("entitlement maps to lifetime once it is owned")
    func ownedLifetimeMapsToEntitlement() async throws {
        let testSession = try session()
        defer { testSession.clearTransactions() }
        let gateway = StoreKitPurchaseGateway()
        _ = try await gateway.purchase(InwardProduct.lifetime.rawValue)

        let owned = await gateway.ownedProductIDs()
        let state = EntitlementPolicy.state(
            trialStartedAt: Date(timeIntervalSince1970: 0),
            now: Date(timeIntervalSince1970: 40 * 86_400),
            ownedProductIDs: owned
        )

        #expect(state == .lifetime)
    }
}
