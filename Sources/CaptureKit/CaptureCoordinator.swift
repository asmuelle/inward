import Foundation
import JournalStore
import Observation

public enum CaptureFailure: Sendable, Equatable {
    case voiceUnavailable
    case captureFailed
    case saveFailed
}

public enum CaptureState: Sendable, Equatable {
    case idle
    case recording(liveTranscript: String)
    case reviewing(draft: String)
    case saving
    case saved(entryID: UUID)
    case failed(CaptureFailure)
}

/// Drives the M1 loop: record → live transcript → review/edit → encrypted save.
/// Voice is optional end to end — `saveWrittenEntry` is the same loop minus the
/// engine, so journaling fully works when ASR is unavailable (invariant #9).
@MainActor
@Observable
public final class CaptureCoordinator {
    public private(set) var state: CaptureState = .idle

    private let engine: (any TranscriptionEngine)?
    private let store: any JournalStoring
    private let now: @Sendable () -> Date
    private let localeIdentifier: String

    private var accumulator = TranscriptAccumulator()
    private var streamTask: Task<Void, Never>?
    private var recordingStartedAt: Date?
    private var rawTranscript: String = ""

    public init(
        engine: (any TranscriptionEngine)?,
        store: any JournalStoring,
        localeIdentifier: String = Locale.current.identifier,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.engine = engine
        self.store = store
        self.localeIdentifier = localeIdentifier
        self.now = now
    }

    // MARK: - Voice path

    public func startRecording() async {
        guard case .idle = state else { return }
        guard let engine, await engine.availability().isAvailable else {
            state = .failed(.voiceUnavailable)
            return
        }
        do {
            let stream = try await engine.start()
            accumulator = TranscriptAccumulator()
            recordingStartedAt = now()
            state = .recording(liveTranscript: "")
            streamTask = Task { [weak self] in
                await self?.consume(stream)
            }
        } catch {
            state = .failed(.captureFailed)
        }
    }

    public func stopRecording() async {
        guard case .recording = state, let engine else { return }
        await engine.stop()
        await streamTask?.value
        streamTask = nil
        rawTranscript = accumulator.displayText
        state = .reviewing(draft: rawTranscript)
    }

    public func updateDraft(_ text: String) {
        guard case .reviewing = state else { return }
        state = .reviewing(draft: text)
    }

    public func saveVoiceEntry() async {
        guard case let .reviewing(draft) = state else { return }
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
        state = .idle
    }

    // MARK: - Internals

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
