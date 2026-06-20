#if canImport(StoreKit)
    import Foundation
    import StoreKit

    /// The shipped gateway: StoreKit 2. Products, purchase, restore, and ownership
    /// all go through Apple — the only network the app touches (invariant #2). No
    /// first-party receipt server exists, so nothing is transmitted anywhere else.
    public struct StoreKitPurchaseGateway: PurchaseGateway {
        public init() {}

        public func availableProducts() async throws -> [PaywallProduct] {
            let products = try await Product.products(for: InwardProduct.allCases.map(\.rawValue))
            return products.compactMap(Self.paywallProduct)
        }

        public func purchase(_ productID: String) async throws -> PurchaseResult {
            guard let product = try await Product.products(for: [productID]).first else {
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

        private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
            switch result {
            case .unverified:
                throw PurchaseError.unverified
            case let .verified(value):
                return value
            }
        }

        private static func paywallProduct(_ product: Product) -> PaywallProduct? {
            guard let kind = InwardProduct(rawValue: product.id) else { return nil }
            let resolvedKind: PaywallProduct.Kind = switch kind {
            case .monthly: .monthly
            case .annual: .annual
            case .lifetime: .lifetime
            }
            return PaywallProduct(
                id: product.id,
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                kind: resolvedKind
            )
        }
    }
#endif
