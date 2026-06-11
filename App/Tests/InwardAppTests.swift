import CaptureKit
import DesignSystem
import Foundation
import JournalStore
import SafetyKit
import Testing

/// Device-level checks for the composed app: the encrypted loop works inside the
/// iOS sandbox, and shipped copy stays clean.
@Suite("Inward app shell")
struct InwardAppTests {
    @Test("the encrypted journaling loop works inside the app sandbox")
    func sandboxJournalingLoop() async throws {
        // Arrange
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("journal.inward")
        let store = EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
        let engine = MockTranscriptionEngine(volatileSegments: ["first"], finalTranscript: "First entry on device.")
        let coordinator = await CaptureCoordinator(engine: engine, store: store, localeIdentifier: "en_US")

        // Act
        await coordinator.startRecording()
        await coordinator.stopRecording()
        await coordinator.saveVoiceEntry()

        // Assert
        let entries = try await store.allEntries()
        #expect(entries.count == 1)
        #expect(entries[0].textEdited == "First entry on device.")
    }

    @Test("all shipped copy passes the banned-terms scan on device")
    func shippedCopyIsClean() {
        for string in Copy.allStrings {
            #expect(BannedTerms.violations(in: string).isEmpty, "banned term in: \(string)")
        }
    }

    @Test("keychain key provider yields a stable key in the sandbox")
    func keychainKeyIsStable() throws {
        // Arrange
        let provider = KeychainKeyProvider(service: "app.inward.tests", account: "test-key-\(UUID().uuidString)")

        // Act
        let first = try provider.key()
        let second = try provider.key()

        // Assert
        #expect(first == second)
    }
}
