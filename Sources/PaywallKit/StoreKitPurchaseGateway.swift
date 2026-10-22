#if canImport(StoreKit)
    import Foundation
    import StoreKit

    /// The shipped gateway: StoreKit 2. Products, purchase, restore, and ownership
    /// all go through Apple — the only network the app touches (invariant #2). No
    /// first-party receipt server exists, so nothing is transmitted anywhere else.
    public struct StoreKitPurchaseGateway: PurchaseGateway {
        public init() {}

        public func availableProducts() async throws -> [PaywallProduct] {
            let products = try await Self.loadProducts(for: InwardProduct.allCases.map(\.rawValue))
            var result: [PaywallProduct] = []
            for product in products {
                if let mapped = await Self.paywallProduct(product) { result.append(mapped) }
            }
            return result
        }

        public func purchase(_ productID: String) async throws -> PurchaseResult {
            guard let product = try await Self.loadProducts(for: [productID]).first else {
                throw PurchaseError.productNotFound
            }
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                let transaction = try Self.verified(verification)
                await transaction.finish()
                return .success
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .pending
            }
        }

        public func restore() async throws {
            try await AppStore.sync()
        }

        public func entitlementUpdates() -> AsyncStream<Void> {
            AsyncStream { continuation in
                let task = Task {
                    // Finish verified transactions (including refunds/renewals) and
                    // signal that entitlement should be recomputed.
                    for await update in Transaction.updates {
                        if case let .verified(transaction) = update {
                            await transaction.finish()
                        }
                        continuation.yield(())
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        public func ownedProductIDs() async -> Set<String> {
            var owned: Set<String> = []
            // currentEntitlements yields only active, non-revoked entitlements:
            // live subscriptions and owned non-consumables.
            for await result in Transaction.currentEntitlements {
                if case let .verified(transaction) = result {
                    owned.insert(transaction.productID)
                }
            }
            return owned
        }

        // MARK: - Helpers

        /// StoreKit product loading is eventually-consistent on a cold start: on a
        /// freshly booted device or CI simulator, `Product.products(for:)` can
        /// briefly return empty before the StoreKit configuration has synced.
        /// Retry a bounded number of times so the paywall is robust on first
        /// launch. Returns immediately once products are available; the final
        /// attempt surfaces a genuine empty result or error unchanged.
        private static func loadProducts(for ids: [String]) async throws -> [Product] {
            for attempt in 0 ..< 10 {
                if let products = try? await Product.products(for: ids), !products.isEmpty {
                    return products
                }
                if attempt < 9 {
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            return try await Product.products(for: ids)
        }

        private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
            switch result {
            case .unverified:
                throw PurchaseError.unverified
            case let .verified(value):
                return value
            }
        }

        private static func paywallProduct(_ product: Product) async -> PaywallProduct? {
            guard let kind = InwardProduct(rawValue: product.id) else { return nil }
            let resolvedKind: PaywallProduct.Kind = switch kind {
            case .monthly: .monthly
            case .annual: .annual
            case .lifetime: .lifetime
            }
            let subscription = product.subscription
            let mappedBillingPeriod: BillingPeriod? = if let subscription {
                Self.billingPeriod(subscription.subscriptionPeriod)
            } else {
                nil
            }
            let introductoryOffer: IntroductoryOffer?
            if let subscription,
               await subscription.isEligibleForIntroOffer,
               let offer = subscription.introductoryOffer,
               offer.paymentMode == .freeTrial
            {
                let base = Self.billingPeriod(offer.period)
                introductoryOffer = IntroductoryOffer(
                    period: BillingPeriod(value: base.value * offer.periodCount, unit: base.unit)
                )
            } else {
                introductoryOffer = nil
            }
            return PaywallProduct(
                id: product.id,
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                kind: resolvedKind,
                billingPeriod: mappedBillingPeriod,
                introductoryOffer: introductoryOffer
            )
        }

        private static func billingPeriod(_ period: Product.SubscriptionPeriod) -> BillingPeriod {
            let unit: BillingPeriod.Unit = switch period.unit {
            case .day: .day
            case .week: .week
            case .month: .month
            case .year: .year
            @unknown default: .month
            }
            return BillingPeriod(value: period.value, unit: unit)
        }
    }
#endif
