import AppIntents
import QuickCaptureKit
import SwiftUI
import WidgetKit

/// Control Center control (iOS 18+) to start a voice entry from the swipe-down
/// panel. The deployment target is iOS 26, so the control type is always available.
struct QuickRecordControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "app.inward.Inward.QuickRecordControl") {
            ControlWidgetButton(action: StartEntryIntent()) {
                Label("New entry", systemImage: "mic.fill")
            }
        }
        .displayName("New Inward entry")
        .description("Start a voice entry.")
    }
}
