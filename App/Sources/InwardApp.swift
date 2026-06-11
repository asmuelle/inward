import CaptureKit
import DesignSystem
import JournalStore
import SwiftUI

/// Composition root only — no business logic lives in the app shell.
@main
struct InwardApp: App {
    private let store: EncryptedFileJournalStore

    init() {
        store = Self.makeStore()
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, engine: Self.makeEngine())
        }
    }

    /// The single encrypted journal file in Application Support, keyed from the
    /// device keychain. Nothing else ever touches disk.
    private static func makeStore() -> EncryptedFileJournalStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let fileURL = base
            .appendingPathComponent("Inward", isDirectory: true)
            .appendingPathComponent("journal.inward")
        return EncryptedFileJournalStore(fileURL: fileURL, keyProvider: KeychainKeyProvider())
    }

    /// On-device ASR when the OS provides it; otherwise nil and the text path
    /// carries the whole journaling loop (invariant #9).
    private static func makeEngine() -> (any TranscriptionEngine)? {
        if #available(iOS 26.0, *) {
            return SpeechTranscriberEngine()
        }
        return nil
    }
}
