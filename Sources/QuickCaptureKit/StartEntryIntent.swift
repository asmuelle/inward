#if canImport(AppIntents)
    import AppIntents

    /// "Start an Inward entry" — the single quick-capture action behind every
    /// system surface (Siri, Shortcuts, Back Tap, the Action Button, widgets, and
    /// Control Center). It opens the app and the app begins recording; nothing runs
    /// off-device, so the privacy promise is untouched.
    @available(iOS 16.0, macOS 13.0, *)
    public struct StartEntryIntent: AppIntent {
        public static let title: LocalizedStringResource = "Start an Inward entry"
        public static let description = IntentDescription(
            "Open Inward and begin a new voice entry."
        )
        /// Brings the app to the foreground and runs `perform()` in its process, so
        /// the in-app signal below reaches the running UI.
        public static let openAppWhenRun = true

        public init() {}

        @MainActor
        public func perform() async throws -> some IntentResult {
            QuickCaptureSignal.shared.requestStart()
            return .result()
        }
    }
#endif
