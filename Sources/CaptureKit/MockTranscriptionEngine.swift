import Foundation

/// Deterministic stand-in for SpeechTranscriber: emits its scripted volatile
/// segments immediately on start, then the final transcript when stopped.
/// Used by tests and previews only — the app never fabricates words.
public actor MockTranscriptionEngine: TranscriptionEngine {
    public nonisolated let engineKind: TranscriptionEngineKind = .mock

    private let volatileSegments: [String]
    private let finalTranscript: String
    private let finalConfidence: Double
    private let reportedAvailability: TranscriptionAvailability
    private var reportedReadiness: TranscriptionAssetReadiness
    private var continuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation?
    private var interruptionStream: AsyncStream<CaptureInterruption>?
    private var interruptionContinuation: AsyncStream<CaptureInterruption>.Continuation?

    /// Test inspection: whether the recording path was ever entered, and whether
    /// the model was explicitly prepared. Lets tests prove recording never starts
    /// (nor downloads) until assets are installed.
    public private(set) var didStart = false
    public private(set) var didPrepare = false
    /// Test inspection: how many times capture was (re)started — a resumed
    /// recording after an interruption counts again.
    public private(set) var startCount = 0
    /// Test inspection: the last vocabulary handed over for recognition biasing.
    public private(set) var receivedVocabulary: [String]?

    public init(
        volatileSegments: [String],
        finalTranscript: String,
        finalConfidence: Double = 0.94,
        availability: TranscriptionAvailability = .available,
        readiness: TranscriptionAssetReadiness = .installed
    ) {
        self.volatileSegments = volatileSegments
        self.finalTranscript = finalTranscript
        self.finalConfidence = finalConfidence
        reportedAvailability = availability
        reportedReadiness = readiness
    }

    public func availability() async -> TranscriptionAvailability {
        reportedAvailability
    }

    public func assetReadiness() async -> TranscriptionAssetReadiness {
        reportedReadiness
    }

    public func prepareAssets() async throws {
        didPrepare = true
        // A successful download leaves the model installed for the next recording.
        reportedReadiness = .installed
    }

    public func start() async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
        guard reportedAvailability.isAvailable else { throw TranscriptionError.notAvailable }
        didStart = true
        startCount += 1
        // A fresh interruption channel per recording, created before `start()`
        // returns so an event fired right after it is buffered, never lost.
        interruptionContinuation?.finish()
        let (interruptions, interruptionContinuation) = AsyncStream<CaptureInterruption>.makeStream()
        interruptionStream = interruptions
        self.interruptionContinuation = interruptionContinuation
        let (stream, continuation) = AsyncThrowingStream<TranscriptSegment, Error>.makeStream()
        self.continuation = continuation
        for text in volatileSegments {
            continuation.yield(TranscriptSegment(text: text, isFinal: false, confidence: 0.5))
        }
        return stream
    }

    public func stop() async {
        continuation?.yield(TranscriptSegment(text: finalTranscript, isFinal: true, confidence: finalConfidence))
        continuation?.finish()
        continuation = nil
    }

    public func setContextualVocabulary(_ terms: [String]) async {
        receivedVocabulary = terms
    }

    /// The channel opened by the most recent `start()`; finished at once if
    /// nothing is recording.
    public func interruptions() async -> AsyncStream<CaptureInterruption> {
        interruptionStream ?? AsyncStream { $0.finish() }
    }

    /// Test control: the system took the microphone (a call, a timer, Siri).
    public func simulateInterruptionBegan() {
        interruptionContinuation?.yield(.began)
    }

    /// Test control: the interruption ended, with the system's recommendation.
    public func simulateInterruptionEnded(shouldResume: Bool) {
        interruptionContinuation?.yield(.ended(shouldResume: shouldResume))
    }
}
