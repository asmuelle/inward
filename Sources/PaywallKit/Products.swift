import Foundation

/// The three things you can buy. Raw values are the App Store product ids; the
/// `.storekit` config and App Store Connect must match them exactly.
public enum InwardProduct: String, CaseIterable, Sendable {
    case monthly = "app.inward.subscription.monthly"
    case annual = "app.inward.subscription.annual"
    case lifetime = "app.inward.lifetime"

    public var isSubscription: Bool {
        self != .lifetime
    }
}

/// A purchasable, display-ready product. The gateway resolves StoreKit `Product`s
/// down to this so the paywall and tests share one value type.
public struct PaywallProduct: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        case monthly
        case annual
        case lifetime
    }

    public let id: String
    public let displayName: String
    public let displayPrice: String
    public let kind: Kind
    public let billingPeriod: BillingPeriod?
    /// Present only when StoreKit says this customer is eligible for a free trial.
    public let introductoryOffer: IntroductoryOffer?

    public init(
        id: String,
        displayName: String,
        displayPrice: String,
        kind: Kind,
        billingPeriod: BillingPeriod? = nil,
        introductoryOffer: IntroductoryOffer? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.kind = kind
        self.billingPeriod = billingPeriod
        self.introductoryOffer = introductoryOffer
    }
}

public struct BillingPeriod: Sendable, Equatable {
    public enum Unit: Sendable, Equatable { case day, week, month, year }

    public let value: Int
    public let unit: Unit

    public init(value: Int, unit: Unit) {
        self.value = value
        self.unit = unit
    }
}

public struct IntroductoryOffer: Sendable, Equatable {
    public let period: BillingPeriod

    public init(period: BillingPeriod) {
        self.period = period
    }
}

public enum PurchaseResult: Sendable, Equatable {
    case success
    case userCancelled
    case pending
    case failed
}

public enum PurchaseError: Error, Equatable {
    case productNotFound
    case unverified
    case failed(String)
}

/// Boundary over StoreKit. The shipped implementation wraps StoreKit 2; tests use
/// the deterministic mock. StoreKit is the *only* network the app may touch
/// (invariant #2); nothing here records analytics (invariant #6).
public protocol PurchaseGateway: Sendable {
    func availableProducts() async throws -> [PaywallProduct]
    func purchase(_ productID: String) async throws -> PurchaseResult
    func restore() async throws
    /// Product ids the user currently owns: active subscriptions and lifetime.
    func ownedProductIDs() async -> Set<String>
    /// Emits whenever entitlements may have changed out of band — a renewal, a
    /// refund (which revokes access), or a purchase approved later (Ask to Buy,
    /// or made on another device). Consumers re-derive entitlement on each element.
    func entitlementUpdates() -> AsyncStream<Void>
}

public extension PaywallProduct {
    /// Sample products for previews and tests, in the annual-first display order.
    static let samples: [PaywallProduct] = [
        PaywallProduct(
            id: InwardProduct.annual.rawValue,
            displayName: "Yearly",
            displayPrice: "$39.99",
            kind: .annual,
            billingPeriod: BillingPeriod(value: 1, unit: .year),
            introductoryOffer: IntroductoryOffer(period: BillingPeriod(value: 1, unit: .week))
        ),
        PaywallProduct(
            id: InwardProduct.monthly.rawValue,
            displayName: "Monthly",
            displayPrice: "$6.99",
            kind: .monthly,
            billingPeriod: BillingPeriod(value: 1, unit: .month),
            introductoryOffer: IntroductoryOffer(period: BillingPeriod(value: 1, unit: .week))
        ),
        PaywallProduct(id: InwardProduct.lifetime.rawValue, displayName: "Lifetime", displayPrice: "$79.99", kind: .lifetime),
    ]
}

/// Deterministic gateway for tests and previews. Purchases and restores mutate an
/// owned set behind an actor; no StoreKit, no network, same result every run.
public actor MockPurchaseGateway: PurchaseGateway {
    private var owned: Set<String>
    private let restorable: Set<String>
    private let products: [PaywallProduct]
    private let purchaseResult: PurchaseResult

    public init(
        products: [PaywallProduct] = PaywallProduct.samples,
        owned: Set<String> = [],
        restorable: Set<String> = [],
        purchaseResult: PurchaseResult = .success
    ) {
        self.products = products
        self.owned = owned
        self.restorable = restorable
        self.purchaseResult = purchaseResult
    }

    public func availableProducts() async throws -> [PaywallProduct] {
        products
    }

    public func purchase(_ productID: String) async throws -> PurchaseResult {
        if purchaseResult == .success { owned.insert(productID) }
        return purchaseResult
    }

    public func restore() async throws {
        owned.formUnion(restorable)
    }

    public func ownedProductIDs() async -> Set<String> {
        owned
    }

    public nonisolated func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}
