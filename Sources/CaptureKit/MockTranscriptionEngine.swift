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

    /// Test inspection: whether the recording path was ever entered, and whether
    /// the model was explicitly prepared. Lets tests prove recording never starts
    /// (nor downloads) until assets are installed.
    public private(set) var didStart = false
    public private(set) var didPrepare = false

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
}
