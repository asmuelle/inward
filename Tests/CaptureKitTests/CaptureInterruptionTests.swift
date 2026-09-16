@testable import CaptureKit
import Foundation
import JournalStore
import Testing

private func temporaryStore() -> EncryptedFileJournalStore {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("inward-interruption-tests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("journal.inward")
    return EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
}

/// Waits for the coordinator to settle into a state matching `predicate`, since
/// interruption events arrive through a stream rather than a direct call.
@MainActor
private func settle(
    _ coordinator: CaptureCoordinator,
    until predicate: (CaptureState) -> Bool
) async -> CaptureState {
    for _ in 0 ..< 200 {
        if predicate(coordinator.state) { return coordinator.state }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return coordinator.state
}

@Suite("CaptureCoordinator — audio interruptions never lose words")
@MainActor
struct CaptureInterruptionTests {
    @Test("an interruption mid-recording parks the words so far instead of failing")
    func interruptionParksDraft() async {
        // Arrange
        let engine = MockTranscriptionEngine(volatileSegments: ["the call"], finalTranscript: "The call came.")
        let coordinator = CaptureCoordinator(engine: engine, store: temporaryStore(), localeIdentifier: "en_US")
        await coordinator.startRecording()

        // Act
        await engine.simulateInterruptionBegan()
        let state = await settle(coordinator) { if case .interrupted = $0 { true } else { false } }

        // Assert — the engine was stopped, so the mock's final segment landed in the draft
        #expect(state == .interrupted(draft: "The call came."))
    }

    @Test("when the system recommends resuming, recording continues and appends")
    func resumptionAppends() async {
        // Arrange
        let engine = MockTranscriptionEngine(volatileSegments: [], finalTranscript: "More words.")
        let coordinator = CaptureCoordinator(engine: engine, store: temporaryStore(), localeIdentifier: "en_US")
        await coordinator.startRecording()
        await engine.simulateInterruptionBegan()
        _ = await settle(coordinator) { if case .interrupted = $0 { true } else { false } }

        // Act
        await engine.simulateInterruptionEnded(shouldResume: true)
        let resumed = await settle(coordinator) { if case .recording = $0 { true } else { false } }
        await coordinator.stopRecording()

        // Assert
        #expect(resumed == .recording(liveTranscript: "More words."))
        #expect(await engine.startCount == 2)
        #expect(coordinator.state == .reviewing(draft: "More words. More words."))
    }

    @Test("when the system advises against resuming, the draft goes to the editor")
    func noResumeGoesToEditor() async {
        // Arrange
        let engine = MockTranscriptionEngine(volatileSegments: [], finalTranscript: "Half a thought.")
        let coordinator = CaptureCoordinator(engine: engine, store: temporaryStore(), localeIdentifier: "en_US")
        await coordinator.startRecording()
        await engine.simulateInterruptionBegan()
        _ = await settle(coordinator) { if case .interrupted = $0 { true } else { false } }

        // Act
        await engine.simulateInterruptionEnded(shouldResume: false)
        let state = await settle(coordinator) { if case .reviewing = $0 { true } else { false } }

        // Assert
        #expect(state == .reviewing(draft: "Half a thought."))
        #expect(await engine.startCount == 1)
    }

    @Test("stopping while interrupted keeps the parked words")
    func stopWhileInterrupted() async {
        // Arrange
        let engine = MockTranscriptionEngine(volatileSegments: [], finalTranscript: "Kept.")
        let coordinator = CaptureCoordinator(engine: engine, store: temporaryStore(), localeIdentifier: "en_US")
        await coordinator.startRecording()
        await engine.simulateInterruptionBegan()
        _ = await settle(coordinator) { if case .interrupted = $0 { true } else { false } }

        // Act
        await coordinator.stopRecording()

        // Assert
        #expect(coordinator.state == .reviewing(draft: "Kept."))
    }

    @Test("the user can choose to continue from the interrupted state")
    func manualContinue() async {
        // Arrange
        let engine = MockTranscriptionEngine(volatileSegments: [], finalTranscript: "Again.")
        let coordinator = CaptureCoordinator(engine: engine, store: temporaryStore(), localeIdentifier: "en_US")
        await coordinator.startRecording()
        await engine.simulateInterruptionBegan()
        _ = await settle(coordinator) { if case .interrupted = $0 { true } else { false } }

        // Act
        await coordinator.continueAfterInterruption()

        // Assert
        #expect(coordinator.state == .recording(liveTranscript: "Again."))
        #expect(await engine.startCount == 2)
    }

    @Test("an interruption event outside recording is ignored")
    func ignoredWhenIdle() async {
        let engine = MockTranscriptionEngine(volatileSegments: [], finalTranscript: "x")
        let coordinator = CaptureCoordinator(engine: engine, store: temporaryStore(), localeIdentifier: "en_US")

        await engine.simulateInterruptionBegan()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(coordinator.state == .idle)
    }
}
