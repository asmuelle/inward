import Foundation

/// The two legal destinations App Review requires on a subscription paywall
/// (Guideline 3.1.2): the hosted privacy policy and the terms of use.
/// Inward has no custom EULA, so terms point at Apple's standard agreement.
enum LegalLinks {
    static let privacyPolicy = URL(string: "https://asmuelle.github.io/inward/privacy.html")!
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
