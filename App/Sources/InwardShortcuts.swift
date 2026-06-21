import AppIntents
import QuickCaptureKit

/// Surfaces the quick-capture intent to Siri and the Shortcuts app, and makes it
/// assignable to Back Tap and the Action Button. The phrases let you say e.g.
/// "Start an Inward entry" to Siri; `\(.applicationName)` resolves to "Inward".
struct InwardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartEntryIntent(),
            phrases: [
                "Start an \(.applicationName) entry",
                "New \(.applicationName) entry",
                "Record in \(.applicationName)",
                "Begin an \(.applicationName) entry",
            ],
            shortTitle: "New entry",
            systemImageName: "mic.circle.fill"
        )
    }
}
