@testable import QuickCaptureKit
import Testing

@Suite("QuickCaptureSignal — quick-capture request token")
struct QuickCaptureSignalTests {
    @MainActor
    @Test("each request bumps the token, so back-to-back triggers both register")
    func incrementsToken() {
        let signal = QuickCaptureSignal.shared
        let before = signal.requestToken

        signal.requestStart()
        signal.requestStart()

        // A counter, not a Bool — two rapid triggers advance it by two, which is
        // what lets the root view distinguish a fresh request from a stale one.
        #expect(signal.requestToken == before + 2)
    }
}
