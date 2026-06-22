@testable import CaptureKit
import Foundation
import JournalStore
import Testing

private func temporaryStore() -> EncryptedFileJournalStore {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("inward-capture-tests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("journal.inward")
    return EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
}

@Suite("CaptureCoordinator — the M1 voice loop")
@MainActor
struct CaptureCoordinatorTests {
    @Test("record → stop → save lands an encrypted entry with transcription provenance")
    func fullVoiceLoopSavesEntry() async throws {
        // Arrange
        let store = temporaryStore()
        let engine = MockTranscriptionEngine(
            volatileSegments: ["the move", "the move keeps"],
            finalTranscript: "The move keeps replaying in my head.",
            finalConfidence: 0.93
        )
        let fixedNow = Date(timeIntervalSince1970: 1_750_000_000)
        let coordinator = CaptureCoordinator(engine: engine, store: store, localeIdentifier: "en_US", now: { fixedNow })

        // Act
        await coordinator.startRecording()
        await coordinator.stopRecording()
        guard case let .reviewing(draft) = coordinator.state else {
            Issue.record("expected reviewing state, got \(coordinator.state)")
            return
        }
        await coordinator.saveVoiceEntry()

        // Assert
        #expect(draft == "The move keeps replaying in my head.")
        guard case let .saved(entryID) = coordinator.state else {
            Issue.record("expected saved state, got \(coordinator.state)")
            return
        }
        let entry = try #require(await store.entry(id: entryID))
        #expect(entry.source == .voice)
        #expect(entry.transcriptRaw == "The move keeps replaying in my head.")
        #expect(entry.textEdited == "The move keeps replaying in my head.")
        #expect(entry.locale == "en_US")
        let transcription = try #require(await store.transcription(entryID: entryID))
        #expect(transcription.engine == .mock)
        #expect(transcription.confidence == 0.93)
    }

    @Test("editing the draft before saving keeps raw transcript as provenance")
    func editedDraftPreservesRawTranscript() async throws {
        // Arrange
        let store = temporaryStore()
        let engine = MockTranscriptionEngine(volatileSegments: [], finalTranscript: "rough words")
        let coordinator = CaptureCoordinator(engine: engine, store: store, localeIdentifier: "en_US")

        // Act
        await coordinator.startRecording()
        await coordinator.stopRecording()
        coordinator.updateDraft("polished words")
        await coordinator.saveVoiceEntry()

        // Assert
        guard case let .saved(entryID) = coordinator.state else {
            Issue.record("expected saved state, got \(coordinator.state)")
            return
        }
        let entry = try #require(await store.entry(id: entryID))
        #expect(entry.transcriptRaw == "rough words")
        #expect(entry.textEdited == "polished words")
    }

    @Test("no engine → voice fails soft; written entry still saves (invariant #9)")
    func textFallbackWorksWithoutEngine() async throws {
        // Arrange
        let store = temporaryStore()
        let coordinator = CaptureCoordinator(engine: nil, store: store, localeIdentifier: "en_US")

        // Act
        await coordinator.startRecording()
        let failedState = coordinator.state
        coordinator.reset()
        await coordinator.saveWrittenEntry("  Typed it instead.  ")

        // Assert
        #expect(failedState == .failed(.voiceUnavailable))
        guard case let .saved(entryID) = coordinator.state else {
            Issue.record("expected saved state, got \(coordinator.state)")
            return
        }
        let entry = try #require(await store.entry(id: entryID))
        #expect(entry.source == .text)
        #expect(entry.textEdited == "Typed it instead.")
        #expect(try await store.transcription(entryID: entryID) == nil)
    }

    @Test("unavailable engine reports voiceUnavailable instead of recording")
    func unavailableEngineFailsSoft() async {
        // Arrange
        let engine = MockTranscriptionEngine(
            volatileSegments: [],
            finalTranscript: "",
            availability: .unavailable(reason: "no speech assets")
        )
        let coordinator = CaptureCoordinator(engine: engine, store: temporaryStore(), localeIdentifier: "en_US")

        // Act
        await coordinator.startRecording()

        // Assert
        #expect(coordinator.state == .failed(.voiceUnavailable))
    }

    @Test("a downloadable model routes to preparation and never starts (no silent download)")
    func downloadableModelRoutesToPreparation() async {
        // Arrange — supported and permitted, but the model isn't installed yet.
        let engine = MockTranscriptionEngine(
            volatileSegments: ["x"],
            finalTranscript: "x",
            readiness: .downloadable
        )
        let coordinator = CaptureCoordinator(engine: engine, store: temporaryStore(), localeIdentifier: "en_US")

        // Act
        await coordinator.startRecording()

        // Assert — capture never began and nothing was fetched mid-recording.
        #expect(coordinator.state == .failed(.voiceNeedsPreparation))
        #expect(await engine.didStart == false)
        #expect(await engine.didPrepare == false)
    }

    @Test("prepareVoice installs the model, then recording proceeds")
    func prepareVoiceThenRecord() async {
        // Arrange
        let engine = MockTranscriptionEngine(
            volatileSegments: ["a"],
            finalTranscript: "a settled thought",
            readiness: .downloadable
        )
        let coordinator = CaptureCoordinator(engine: engine, store: temporaryStore(), localeIdentifier: "en_US")

        // Act — the one consented download returns us to idle…
        let ready = await coordinator.prepareVoice()

        // Assert
        #expect(ready)
        #expect(await engine.didPrepare)
        #expect(coordinator.state == .idle)

        // …and recording then starts normally.
        await coordinator.startRecording()
        #expect(await engine.didStart)
        guard case .recording = coordinator.state else {
            Issue.record("expected recording state, got \(coordinator.state)")
            return
        }
    }

    @Test("blank written entries are ignored, state stays idle")
    func blankWrittenEntryIgnored() async throws {
        // Arrange
        let store = temporaryStore()
        let coordinator = CaptureCoordinator(engine: nil, store: store, localeIdentifier: "en_US")

        // Act
        await coordinator.saveWrittenEntry("   \n  ")

        // Assert
        #expect(coordinator.state == .idle)
        #expect(try await store.allEntries().isEmpty)
    }

    @Test("reset returns to idle from any state")
    func resetReturnsToIdle() async {
        // Arrange
        let engine = MockTranscriptionEngine(volatileSegments: ["a"], finalTranscript: "a b c")
        let coordinator = CaptureCoordinator(engine: engine, store: temporaryStore(), localeIdentifier: "en_US")
        await coordinator.startRecording()
        await coordinator.stopRecording()

        // Act
        coordinator.reset()

        // Assert
        #expect(coordinator.state == .idle)
    }
}
