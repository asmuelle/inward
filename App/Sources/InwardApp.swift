import CaptureKit
import DesignSystem
import InsightKit
import JournalStore
import JournalStoreSQLCipher
import PaywallKit
import PrivacyKit
import ReflectKit
import SwiftUI

/// Composition root only — no business logic lives in the app shell.
@main
struct InwardApp: App {
    private let store: any JournalStoring

    init() {
        store = Self.makeStore()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                store: store,
                engine: Self.makeEngine(),
                reviewProvider: Self.makeReviewProvider(),
                entityExtractor: Self.makeEntityExtractor(),
                authenticator: LocalAuthenticationAuthenticator(),
                purchaseGateway: StoreKitPurchaseGateway(),
                trialStartedAt: Prefs.trialStart()
            )
        }
    }

    /// On-device weekly-review synthesis via FoundationModels. When Apple
    /// Intelligence is unavailable the surface degrades to deterministic recurring
    /// themes (handled in WeeklyReviewModel), so the feature is never empty.
    private static func makeReviewProvider() -> any WeeklyReviewProviding {
        FoundationModelsWeeklyReviewProvider()
    }

    /// Entity/topic extraction for the background indexer: Apple Intelligence when
    /// present, the deterministic NaturalLanguage floor otherwise. The indexer also
    /// falls back per-run if the model turns out unavailable (invariant #9).
    private static func makeEntityExtractor() -> any EntityExtracting {
        if #available(iOS 26.0, macOS 26.0, *) {
            return FoundationModelsEntityExtractor()
        }
        return NaturalLanguageEntityExtractor()
    }

    /// The SQLCipher-encrypted journal database in Application Support, keyed from
    /// the device keychain. If the database cannot be opened, journaling must still
    /// work, so it falls back to the M1 encrypted file store (invariant #9).
    private static func makeStore() -> any JournalStoring {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            .map { $0.appendingPathComponent("Inward", isDirectory: true) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("Inward", isDirectory: true)
        let keyProvider = KeychainKeyProvider()
        do {
            return try SQLCipherJournalStore(
                fileURL: directory.appendingPathComponent("journal.db"),
                keyProvider: keyProvider
            )
        } catch {
            return EncryptedFileJournalStore(
                fileURL: directory.appendingPathComponent("journal.inward"),
                keyProvider: keyProvider
            )
        }
    }

    /// On-device ASR when the OS provides it; otherwise nil and the text path
    /// carries the whole journaling loop (invariant #9). Available on iOS 26 and
    /// macOS 26 — the engine shares its capture core across both.
    private static func makeEngine() -> (any TranscriptionEngine)? {
        if #available(iOS 26.0, macOS 26.0, *) {
            return SpeechTranscriberEngine()
        }
        return nil
    }
}
