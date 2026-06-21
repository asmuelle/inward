import SwiftUI
import WidgetKit

/// Inward's widget surfaces: a tap-to-record Home/Lock-Screen widget and a
/// Control Center control. Both run the shared StartEntryIntent, so every entry
/// point opens the app straight into recording. iOS-only (the macOS app omits it).
@main
struct InwardWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickRecordWidget()
        QuickRecordControl()
    }
}
