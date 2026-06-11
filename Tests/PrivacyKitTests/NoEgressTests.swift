import CaptureKit
import Foundation
import JournalStore
@testable import PrivacyKit
import Testing

private func temporaryStore() -> EncryptedFileJournalStore {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("inward-noegress-tests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("journal.inward")
    return EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
}

/// Serialized: the recorder is global state shared with the interceptor.
@Suite("NoEgress harness — invariant #2 as executable code", .serialized)
struct NoEgressTests {
    @Test("the interceptor records and blocks any request on a monitored session")
    func interceptorBlocksAndRecords() async throws {
        // Arrange
        NoEgressRecorder.shared.reset()
        let session = URLSession(configuration: NoEgress.monitoredConfiguration())
        let url = try #require(URL(string: "https://example.invalid/should-never-leave"))

        // Act
        var failedAsExpected = false
        do {
            _ = try await session.data(from: url)
        } catch {
            failedAsExpected = true
        }

        // Assert
        #expect(failedAsExpected, "the blocked request must surface as an error")
        let attempted = NoEgressRecorder.shared.snapshot()
        #expect(attempted.contains { $0.url?.host == "example.invalid" })
    }

    @Test("the full M1 journaling loop attempts zero network requests")
    func journalingLoopHasZeroEgress() async throws {
        // Arrange
        let store = temporaryStore()
        let engine = MockTranscriptionEngine(
            volatileSegments: ["quiet evening"],
            finalTranscript: "Quiet evening, first one in weeks."
        )

        // Act — capture → transcribe → save → list → reopen, fully observed
        let (savedID, attempted) = try await NoEgress.observe {
            let coordinator = await CaptureCoordinator(engine: engine, store: store, localeIdentifier: "en_US")
            await coordinator.startRecording()
            await coordinator.stopRecording()
            await coordinator.saveVoiceEntry()
            let entries = try await store.allEntries()
            _ = try await store.entry(id: entries[0].id)
            return entries[0].id
        }

        // Assert
        #expect(attempted.isEmpty, "journaling path attempted network requests: \(attempted)")
        #expect(try await store.entry(id: savedID) != nil)
    }

    @Test("observe restores a clean recorder per run")
    func observeIsolatesRuns() async throws {
        // Act
        let (_, first) = try await NoEgress.observe { 1 }
        let (_, second) = try await NoEgress.observe { 2 }

        // Assert
        #expect(first.isEmpty)
        #expect(second.isEmpty)
    }
}
