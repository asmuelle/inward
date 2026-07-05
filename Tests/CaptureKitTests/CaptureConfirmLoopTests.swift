@testable import CaptureKit
import Foundation
import JournalStore
import SafetyKit
import Testing

private func temporaryStore() -> EncryptedFileJournalStore {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("inward-confirm-tests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("journal.inward")
    return EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
}

/// Builds a coordinator wired with the spoken-recap loop, returning the synth
/// mock so tests can inspect what was spoken.
@MainActor
private func makeCoordinator(
    store: EncryptedFileJournalStore,
    finalTranscript: String,
    summary: String = "You talked about the long day.",
    clarification: String = "What part stayed with you?",
    summaryAvailability: CaptureSummaryAvailability = .available,
    maxRounds: Int = 2
) -> (CaptureCoordinator, MockSpeechSynthesisEngine) {
    let engine = MockTranscriptionEngine(volatileSegments: [], finalTranscript: finalTranscript)
    let provider = MockCaptureSummaryProvider(
        summary: summary,
        clarification: clarification,
        availability: summaryAvailability
    )
    let synth = MockSpeechSynthesisEngine()
    let coordinator = CaptureCoordinator(
        engine: engine,
        store: store,
        summaryPipeline: CaptureSummaryPipeline(provider: provider),
        synthesizer: synth,
        localeIdentifier: "en_US",
        maxClarificationRounds: maxRounds,
        now: { Date(timeIntervalSince1970: 1_750_000_000) }
    )
    return (coordinator, synth)
}

@Suite("CaptureCoordinator — spoken confirm loop")
@MainActor
struct CaptureConfirmLoopTests {
    @Test("record → stop speaks the recap and lands on confirming")
    func stopEntersConfirmingAndSpeaks() async {
        // Arrange
        let store = temporaryStore()
        let (coordinator, synth) = makeCoordinator(
            store: store,
            finalTranscript: "Today ran long and I felt thin.",
            summary: "You said the day ran long."
        )

        // Act
        await coordinator.startRecording()
        await coordinator.stopRecording()

        // Assert
        guard case let .confirming(draft, summary) = coordinator.state else {
            Issue.record("expected confirming, got \(coordinator.state)")
            return
        }
        #expect(draft == "Today ran long and I felt thin.")
        #expect(summary == "You said the day ran long.")
        #expect(await synth.spokenUtterances == ["You said the day ran long."])
    }

    @Test("Keep from confirming saves the entry")
    func confirmKeepSaves() async throws {
        // Arrange
        let store = temporaryStore()
        let (coordinator, _) = makeCoordinator(store: store, finalTranscript: "A small win today.")

        // Act
        await coordinator.startRecording()
        await coordinator.stopRecording()
        await coordinator.confirmKeep()

        // Assert
        guard case let .saved(entryID) = coordinator.state else {
            Issue.record("expected saved, got \(coordinator.state)")
            return
        }
        let entry = try #require(await store.entry(id: entryID))
        #expect(entry.source == .voice)
        #expect(entry.textEdited == "A small win today.")
    }

    @Test("Add more speaks a question, re-records, and appends to the draft")
    func addMoreAppendsAcrossRounds() async {
        // Arrange — the mock engine emits the same final each recording; the
        // second round must append rather than replace.
        let store = temporaryStore()
        let (coordinator, synth) = makeCoordinator(
            store: store,
            finalTranscript: "I keep replaying it.",
            summary: "You keep replaying it.",
            clarification: "What keeps pulling you back?"
        )

        // Act — first round → confirming → Add more → second recording → stop.
        await coordinator.startRecording()
        await coordinator.stopRecording()
        await coordinator.requestClarification()

        // After requestClarification the question was spoken and the mic re-armed.
        guard case let .recording(live) = coordinator.state else {
            Issue.record("expected recording after Add more, got \(coordinator.state)")
            return
        }
        #expect(live == "I keep replaying it.") // seeded with the prior draft
        #expect(await synth.spokenUtterances == ["You keep replaying it.", "What keeps pulling you back?"])

        await coordinator.stopRecording()

        // Assert — the second round's transcript appended to the first.
        guard case let .confirming(draft, _) = coordinator.state else {
            Issue.record("expected confirming after second stop, got \(coordinator.state)")
            return
        }
        #expect(draft == "I keep replaying it. I keep replaying it.")
    }

    @Test("clarification rounds are capped, then it drops to the editor")
    func clarificationRoundCap() async {
        // Arrange — one round allowed.
        let store = temporaryStore()
        let (coordinator, _) = makeCoordinator(
            store: store,
            finalTranscript: "still thinking",
            maxRounds: 1
        )

        // Act — round 1 consumes the only allowance.
        await coordinator.startRecording()
        await coordinator.stopRecording()
        await coordinator.requestClarification() // → recording (round 1)
        await coordinator.stopRecording() // → confirming again
        await coordinator.requestClarification() // cap hit

        // Assert — falls back to the editor with the draft intact.
        guard case .reviewing = coordinator.state else {
            Issue.record("expected reviewing after cap, got \(coordinator.state)")
            return
        }
    }

    @Test("crisis content skips the recap and saves quietly")
    func crisisSkipsRecapAndSaves() async throws {
        // Arrange — the spoken summary would fire, but the gate must pre-empt it.
        let store = temporaryStore()
        let (coordinator, synth) = makeCoordinator(
            store: store,
            finalTranscript: "Lately I just want to die.",
            summary: "should never be spoken"
        )

        // Act
        await coordinator.startRecording()
        await coordinator.stopRecording()

        // Assert — saved without ever speaking or showing a confirm/upsell.
        guard case let .saved(entryID) = coordinator.state else {
            Issue.record("expected saved, got \(coordinator.state)")
            return
        }
        #expect(await synth.spokenUtterances.isEmpty)
        let entry = try #require(await store.entry(id: entryID))
        #expect(entry.transcriptRaw == "Lately I just want to die.")
    }

    @Test("an unavailable summary model falls back to the read-it-back editor")
    func unavailableModelFallsBackToEditor() async {
        // Arrange
        let store = temporaryStore()
        let (coordinator, synth) = makeCoordinator(
            store: store,
            finalTranscript: "an ordinary note",
            summaryAvailability: .unavailable(reason: "no AI")
        )

        // Act
        await coordinator.startRecording()
        await coordinator.stopRecording()

        // Assert — exactly today's behavior, nothing spoken.
        guard case let .reviewing(draft) = coordinator.state else {
            Issue.record("expected reviewing, got \(coordinator.state)")
            return
        }
        #expect(draft == "an ordinary note")
        #expect(await synth.spokenUtterances.isEmpty)
    }

    @Test("without the spoken-loop deps, capture behaves exactly as before")
    func noDepsPreservesLegacyPath() async {
        // Arrange — no summaryPipeline, no synthesizer.
        let store = temporaryStore()
        let engine = MockTranscriptionEngine(volatileSegments: [], finalTranscript: "plain")
        let coordinator = CaptureCoordinator(engine: engine, store: store, localeIdentifier: "en_US")

        // Act
        await coordinator.startRecording()
        await coordinator.stopRecording()

        // Assert
        guard case let .reviewing(draft) = coordinator.state else {
            Issue.record("expected reviewing, got \(coordinator.state)")
            return
        }
        #expect(draft == "plain")
    }
}
