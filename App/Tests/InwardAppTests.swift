import CaptureKit
import DesignSystem
import Foundation
@testable import Inward
import JournalStore
import ReflectKit
import SafetyKit
import Testing

private struct FixedReflectionProvider: ReflectionProviding {
    let prompt: ReflectionPrompt

    func availability() async -> ReflectionAvailability {
        .available
    }

    func reflection(for _: String) async throws -> ReflectionPrompt {
        prompt
    }
}

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

    @MainActor
    @Test("entry detail reflection model runs the guarded reflection pipeline")
    func entryReflectionLoads() async {
        let expected = ReflectionPrompt(questions: ["What stayed with you?"], themes: ["morning"])
        let provider = FixedReflectionProvider(prompt: expected)
        let model = EntryReflectionModel(
            entryText: "A slow morning by the window.",
            pipeline: ReflectionPipeline(provider: provider)
        )

        await model.load()

        #expect(model.outcome == .reflection(expected))
    }

    @MainActor
    @Test("timeline reports encrypted database failures instead of an empty journal")
    func timelineReportsStoreFailure() async {
        let model = TimelineModel(store: UnavailableJournalStore(error: .corruptDatabase))

        await model.refresh()

        #expect(model.loadFailed)
        #expect(model.entries.isEmpty)
    }
}
