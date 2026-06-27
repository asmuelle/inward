import Foundation
import JournalStore
import Observation

public enum CaptureFailure: Sendable, Equatable {
    case voiceUnavailable
    /// Voice is supported but its on-device model isn't installed yet. The UI
    /// offers a one-time, consented download rather than fetching mid-recording.
    case voiceNeedsPreparation
    case captureFailed
    case saveFailed
}

public enum CaptureState: Sendable, Equatable {
    case idle
    case recording(liveTranscript: String)
    /// Generating and speaking the spoken recap — transient, shows a spinner.
    case summarizing(draft: String)
    /// Recap spoken; awaiting Keep / Add more / Discard.
    case confirming(draft: String, summary: String)
    /// Speaking the clarification question before the mic re-arms — transient.
    case clarifying(draft: String, question: String)
    case reviewing(draft: String)
    case saving
    case saved(entryID: UUID)
    case failed(CaptureFailure)
}

/// Drives the capture loop: record → live transcript → (optional spoken recap →
/// keep/expand confirm) → encrypted save. Voice is optional end to end —
/// `saveWrittenEntry` is the same loop minus the engine, so journaling fully
/// works when ASR is unavailable (invariant #9). The spoken-recap loop is itself
/// optional: it runs only when both a synthesizer and a summary pipeline are
/// injected, otherwise capture falls straight through to the read-it-back editor.
@MainActor
@Observable
public final class CaptureCoordinator {
    public private(set) var state: CaptureState = .idle

    private let engine: (any TranscriptionEngine)?
    private let store: any JournalStoring
    private let summaryPipeline: CaptureSummaryPipeline?
    private let synthesizer: (any SpeechSynthesisEngine)?
    private let now: @Sendable () -> Date
    private let localeIdentifier: String
    private let maxClarificationRounds: Int

    private var accumulator = TranscriptAccumulator()
    private var streamTask: Task<Void, Never>?
    private var recordingStartedAt: Date?
    private var rawTranscript: String = ""
    private var clarificationRounds = 0

    public init(
        engine: (any TranscriptionEngine)?,
        store: any JournalStoring,
        summaryPipeline: CaptureSummaryPipeline? = nil,
        synthesizer: (any SpeechSynthesisEngine)? = nil,
        localeIdentifier: String = Locale.current.identifier,
        maxClarificationRounds: Int = 2,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.engine = engine
        self.store = store
        self.summaryPipeline = summaryPipeline
        self.synthesizer = synthesizer
        self.localeIdentifier = localeIdentifier
        self.maxClarificationRounds = maxClarificationRounds
        self.now = now
    }

    // MARK: - Voice path

    public func startRecording() async {
        guard case .idle = state else { return }
        guard let engine, await engine.availability().isAvailable else {
            state = .failed(.voiceUnavailable)
            return
        }
        // Never let recording trigger a model download — that would breach the
        // airplane-mode promise (invariant #2). If the model isn't installed yet,
        // route to the consented preflight instead of starting capture.
        guard await engine.assetReadiness().isInstalled else {
            state = .failed(.voiceNeedsPreparation)
            return
        }
        do {
            let stream = try await engine.start()
            accumulator = TranscriptAccumulator()
            recordingStartedAt = now()
            clarificationRounds = 0
            state = .recording(liveTranscript: "")
            streamTask = Task { [weak self] in
                await self?.consume(stream)
            }
        } catch {
            state = .failed(.captureFailed)
        }
    }

    /// Downloads the on-device voice model — the one consented network step,
    /// invoked only from the preparation prompt, never implicitly. Returns to
    /// idle on success so the next recording works fully offline; reports
    /// `voiceUnavailable` on failure so the writer is never stranded.
    @discardableResult
    public func prepareVoice() async -> Bool {
        guard let engine else {
            state = .failed(.voiceUnavailable)
            return false
        }
        do {
            try await engine.prepareAssets()
            state = .idle
            return true
        } catch {
            state = .failed(.voiceUnavailable)
            return false
        }
    }

    public func stopRecording() async {
        guard case .recording = state, let engine else { return }
        await engine.stop()
        await streamTask?.value
        streamTask = nil
        rawTranscript = accumulator.displayText
        await presentRecap(draft: rawTranscript)
    }

    public func updateDraft(_ text: String) {
        guard case .reviewing = state else { return }
        state = .reviewing(draft: text)
    }

    /// Keeps the entry from the read-it-back editor (the non-spoken path).
    public func saveVoiceEntry() async {
        guard case let .reviewing(draft) = state else { return }
        await commit(draft: draft)
    }

    /// "Keep" from the spoken confirm screen.
    public func confirmKeep() async {
        guard case let .confirming(draft, _) = state else { return }
        await commit(draft: draft)
    }

    /// "Add more" from the spoken confirm screen: ask one open question, speak it,
    /// then re-arm the mic so new speech appends to the existing draft. Capped at
    /// `maxClarificationRounds`; on the cap (or any soft failure) it drops back to
    /// the editor so the draft is never lost.
    public func requestClarification() async {
        guard case let .confirming(draft, _) = state else { return }
        guard clarificationRounds < maxClarificationRounds,
              let synthesizer, let summaryPipeline
        else {
            state = .reviewing(draft: draft)
            return
        }
        clarificationRounds += 1
        state = .clarifying(draft: draft, question: "")
        switch await summaryPipeline.clarify(draft) {
        case .suppressed:
            // Crisis content surfaced mid-loop — stop asking, save quietly.
            await commit(draft: draft)
        case let .question(question):
            state = .clarifying(draft: draft, question: question)
            await synthesizer.speak(question, locale: localeIdentifier)
            guard case .clarifying = state else { return } // user bailed mid-speech
            await resumeRecording(appendingTo: draft)
        case .unavailable:
            state = .reviewing(draft: draft)
        }
    }

    // MARK: - Text path (always available)

    public func saveWrittenEntry(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = Entry(
            createdAt: now(),
            source: .text,
            transcriptRaw: trimmed,
            textEdited: trimmed,
            locale: localeIdentifier
        )
        await persist(entry: entry, transcription: nil)
    }

    public func reset() {
        streamTask?.cancel()
        streamTask = nil
        accumulator = TranscriptAccumulator()
        rawTranscript = ""
        recordingStartedAt = nil
        clarificationRounds = 0
        state = .idle
    }

    // MARK: - Internals

    /// After a recording stops, either run the spoken recap loop or fall through
    /// to the silent editor. The model is reached only through the pipeline, which
    /// gates on crisis content first and validates output after.
    private func presentRecap(draft: String) async {
        guard let synthesizer, let summaryPipeline else {
            state = .reviewing(draft: draft)
            return
        }
        state = .summarizing(draft: draft)
        switch await summaryPipeline.summarize(draft) {
        case .suppressed:
            // Never recap or upsell over crisis content — save the entry quietly
            // and let the app's safety surfaces present resources.
            await commit(draft: draft)
        case let .summary(summary):
            await synthesizer.speak(summary, locale: localeIdentifier)
            guard case .summarizing = state else { return } // user bailed mid-speech
            state = .confirming(draft: draft, summary: summary)
        case .unavailable:
            state = .reviewing(draft: draft)
        }
    }

    /// Re-arms the mic for another clarification round, seeding the accumulator
    /// with the prior draft so new speech appends to it. Never downloads — if the
    /// model isn't installed the draft is kept in the editor instead.
    private func resumeRecording(appendingTo draft: String) async {
        guard let engine else {
            state = .reviewing(draft: draft)
            return
        }
        guard await engine.assetReadiness().isInstalled else {
            state = .reviewing(draft: draft)
            return
        }
        do {
            let stream = try await engine.start()
            accumulator = TranscriptAccumulator(committed: draft)
            state = .recording(liveTranscript: draft)
            streamTask = Task { [weak self] in
                await self?.consume(stream)
            }
        } catch {
            state = .reviewing(draft: draft)
        }
    }

    private func commit(draft: String) async {
        let started = recordingStartedAt
        let entry = Entry(
            createdAt: now(),
            source: .voice,
            transcriptRaw: rawTranscript,
            textEdited: draft,
            durationSec: started.map { now().timeIntervalSince($0) },
            locale: localeIdentifier
        )
        let transcription = Transcription(
            entryId: entry.id,
            engine: transcriptionEngineLabel,
            confidence: accumulator.lastFinalConfidence ?? 0,
            completedAt: now()
        )
        await persist(entry: entry, transcription: transcription)
    }

    private func consume(_ stream: AsyncThrowingStream<TranscriptSegment, Error>) async {
        do {
            for try await segment in stream {
                accumulator = accumulator.merging(segment)
                if case .recording = state {
                    state = .recording(liveTranscript: accumulator.displayText)
                }
            }
        } catch {
            state = .failed(.captureFailed)
        }
    }

    private func persist(entry: Entry, transcription: Transcription?) async {
        state = .saving
        do {
            try await store.save(entry: entry, transcription: transcription)
            state = .saved(entryID: entry.id)
        } catch {
            state = .failed(.saveFailed)
        }
    }

    private var transcriptionEngineLabel: Transcription.Engine {
        switch engine?.engineKind {
        case .speechTranscriber: .speechTranscriber
        case .whisper: .whisper
        case .mock, .none: .mock
        }
    }
}
