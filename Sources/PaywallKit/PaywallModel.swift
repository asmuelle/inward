import Foundation

/// Drives the paywall and the app's lock state: loads products, runs purchase and
/// restore through the gateway, and derives the entitlement from owned products
/// plus the trial clock via the pure `EntitlementPolicy`. UI-facing, so it lives
/// on the main actor; testable on macOS because the gateway is a protocol.
@MainActor
@Observable
public final class PaywallModel {
    public private(set) var products: [PaywallProduct] = []
    public private(set) var entitlement: EntitlementState
    public private(set) var isWorking = false
    public private(set) var lastErrorMessage: String?

    private let gateway: any PurchaseGateway
    private let trialStartedAt: Date
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        gateway: any PurchaseGateway,
        trialStartedAt: Date,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.gateway = gateway
        self.trialStartedAt = trialStartedAt
        self.now = now
        self.calendar = calendar
        entitlement = EntitlementPolicy.state(
            trialStartedAt: trialStartedAt,
            now: now(),
            ownedProductIDs: [],
            calendar: calendar
        )
    }

    /// New captures are gated when the trial has lapsed without a purchase.
    /// Reading and export are never gated (invariant #8).
    public var isLocked: Bool { !EntitlementPolicy.isCaptureAllowed(entitlement) }

    /// Load products and recompute entitlement from current ownership.
    public func refresh() async {
        let loaded = (try? await gateway.availableProducts()) ?? []
        let owned = await gateway.ownedProductIDs()
        products = Self.annualFirst(loaded)
        entitlement = EntitlementPolicy.state(
            trialStartedAt: trialStartedAt,
            now: now(),
            ownedProductIDs: owned,
            calendar: calendar
        )
    }

    @discardableResult
    public func purchase(_ productID: String) async -> PurchaseResult {
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }
        do {
            let result = try await gateway.purchase(productID)
            await refresh()
            return result
        } catch {
            lastErrorMessage = String(describing: error)
            return .pending
        }
    }

    /// Long-lived: re-derives entitlement whenever StoreKit reports a change
    /// (renewal, refund, out-of-band purchase). Start once at launch.
    public func observeUpdates() async {
        for await _ in gateway.entitlementUpdates() {
            await refresh()
        }
    }

    public func restore() async {
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }
        do {
            try await gateway.restore()
            await refresh()
        } catch {
            lastErrorMessage = String(describing: error)
        }
    }

    /// Annual highlighted first, then monthly, then lifetime.
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
