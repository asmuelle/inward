import Foundation

/// One piece of live transcript. Volatile segments replace the current hypothesis;
/// final segments are committed in order.
public struct TranscriptSegment: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool
    public let confidence: Double

    public init(text: String, isFinal: Bool, confidence: Double = 1.0) {
        self.text = text
        self.isFinal = isFinal
        self.confidence = confidence
    }
}

public enum TranscriptionAvailability: Sendable, Equatable {
    case available
    case unavailable(reason: String)

    public var isAvailable: Bool {
        self == .available
    }
}

public enum TranscriptionError: Error, Equatable {
    case notAvailable
    case audioSetupFailed(String)
    case engineFailed(String)
}

/// Boundary for on-device ASR. The real engine wraps SpeechTranscriber on iOS 26;
/// tests and previews use the deterministic mock. Journaling never requires this
/// to exist — text entry is always a full citizen (product invariant #9).
public protocol TranscriptionEngine: Sendable {
    /// Provenance label recorded with each transcription.
    var engineKind: TranscriptionEngineKind { get }

    func availability() async -> TranscriptionAvailability

    /// Starts capture and returns the live segment stream. The stream finishes
    /// after `stop()` has been called and the final segment has been delivered.
    func start() async throws -> AsyncThrowingStream<TranscriptSegment, Error>

    func stop() async
}

public enum TranscriptionEngineKind: String, Sendable {
    case speechTranscriber
    case whisper
    case mock
}
