public enum EntitlementState: Sendable, Equatable {
    case active
    case lifetime
    case expired
}

/// StoreKit ownership is the only paid-access authority. The app deliberately has
/// no install-date clock: introductory-offer eligibility belongs to StoreKit and
/// therefore cannot be reset by reinstalling the app or changing the device clock.
public enum EntitlementPolicy {
    public static func state(ownedProductIDs: Set<String>) -> EntitlementState {
        if ownedProductIDs.contains(InwardProduct.lifetime.rawValue) { return .lifetime }
        if ownedProductIDs.contains(InwardProduct.monthly.rawValue)
            || ownedProductIDs.contains(InwardProduct.annual.rawValue)
        {
            return .active
        }
        return .expired
    }

    /// Capture is free, forever, in every state. Writing down what you said is
    /// the thing the app is *for*; charging for it caps the habit that makes the
    /// paid part worth anything, and a journal you can be locked out of adding to
    /// is not a journal. The paid tier is generated insight — see
    /// `isInsightAllowed`.
    public static func isCaptureAllowed(_: EntitlementState) -> Bool {
        true
    }

    public static func isInsightAllowed(_ state: EntitlementState) -> Bool {
        state != .expired
    }

    public static func isReadingAllowed(_: EntitlementState) -> Bool {
        true
    }

    public static func isExportAllowed(_: EntitlementState) -> Bool {
        true
    }
}

/// Capture is never limited, so this policy no longer gates anything: it marks
/// the one moment — the third saved entry — where there is finally enough
/// material for a deterministic, citation-backed First Look at what the paid
/// tier would show. Entry-count based, never described as a trial, and it cannot
/// grant paid insight access.
public enum FreeSamplePolicy {
    public static let entryLimit = 3

    public static func shouldPresentFirstLook(
        previousCount: Int,
        currentCount: Int,
        alreadyShown: Bool
    ) -> Bool {
        !alreadyShown && previousCount < entryLimit && currentCount >= entryLimit
    }
}
