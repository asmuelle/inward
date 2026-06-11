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
    private var continuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation?

    public init(
        volatileSegments: [String],
        finalTranscript: String,
        finalConfidence: Double = 0.94,
        availability: TranscriptionAvailability = .available
    ) {
        self.volatileSegments = volatileSegments
        self.finalTranscript = finalTranscript
        self.finalConfidence = finalConfidence
        reportedAvailability = availability
    }

    public func availability() async -> TranscriptionAvailability {
        reportedAvailability
    }

    public func start() async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
        guard reportedAvailability.isAvailable else { throw TranscriptionError.notAvailable }
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
