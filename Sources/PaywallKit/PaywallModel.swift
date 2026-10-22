import Foundation

private enum PaywallModelError: Error { case noProducts }

public enum PaywallLoadState: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
public final class PaywallModel {
    public private(set) var products: [PaywallProduct] = []
    public private(set) var entitlement: EntitlementState = .expired
    public private(set) var loadState: PaywallLoadState = .idle
    public private(set) var isWorking = false
    public private(set) var lastErrorMessage: String?

    private let gateway: any PurchaseGateway

    public init(gateway: any PurchaseGateway) {
        self.gateway = gateway
    }

    /// Deliberately absent: there is no `isCaptureLocked`. Capture is free in
    /// every entitlement state, so a property that is always `false` would only
    /// invite call sites to gate on it again.
    public var isInsightLocked: Bool {
        !EntitlementPolicy.isInsightAllowed(entitlement)
    }

    public func refresh() async {
        loadState = .loading
        lastErrorMessage = nil
        do {
            let loaded = try await gateway.availableProducts()
            guard !loaded.isEmpty else { throw PaywallModelError.noProducts }
            let owned = await gateway.ownedProductIDs()
            products = Self.annualFirst(loaded)
            entitlement = EntitlementPolicy.state(ownedProductIDs: owned)
            loadState = .loaded
        } catch {
            products = []
            entitlement = await EntitlementPolicy.state(ownedProductIDs: gateway.ownedProductIDs())
            lastErrorMessage = "productsUnavailable"
            loadState = .failed
        }
    }

    @discardableResult
    public func purchase(_ productID: String) async -> PurchaseResult {
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }
        do {
            let result = try await gateway.purchase(productID)
            await refreshEntitlement()
            return result
        } catch {
            lastErrorMessage = "purchaseFailed"
            return .failed
        }
    }

    public func observeUpdates() async {
        for await _ in gateway.entitlementUpdates() {
            await refreshEntitlement()
        }
    }

    public func restore() async {
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }
        do {
            try await gateway.restore()
            await refreshEntitlement()
        } catch {
            lastErrorMessage = "restoreFailed"
        }
    }

    private func refreshEntitlement() async {
        entitlement = await EntitlementPolicy.state(ownedProductIDs: gateway.ownedProductIDs())
    }

    static func annualFirst(_ products: [PaywallProduct]) -> [PaywallProduct] {
        func rank(_ kind: PaywallProduct.Kind) -> Int {
            switch kind {
            case .annual: 0
            case .monthly: 1
            case .lifetime: 2
            }
        }
        return products.sorted { rank($0.kind) < rank($1.kind) }
    }
}
