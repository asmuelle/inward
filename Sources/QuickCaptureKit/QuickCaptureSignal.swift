import Foundation
import Observation

/// The bridge between a quick-capture trigger (Siri, Shortcuts, Back Tap, the
/// Action Button, a widget, or a Control Center control) and the running app.
///
/// `StartEntryIntent` runs in the app process when invoked (its `openAppWhenRun`
/// brings the app forward), bumps `requestToken`, and the root view observes that
/// to begin recording. A monotonically increasing token — rather than a Bool — so
/// repeated triggers each register, even back to back.
@MainActor
@Observable
public final class QuickCaptureSignal {
    public static let shared = QuickCaptureSignal()

    public private(set) var requestToken = 0

    private init() {}

    /// Request that the app start a new voice entry. Safe to call repeatedly.
    public func requestStart() {
        requestToken += 1
    }
}
