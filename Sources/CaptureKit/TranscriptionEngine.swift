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
    /// The on-device model for the locale isn't installed yet. Recording never
    /// downloads it (that would breach the airplane-mode promise) — the model
    /// must be prepared first via an explicit, consented preflight.
    case assetsNotInstalled
    case audioSetupFailed(String)
    case engineFailed(String)
}

/// Whether the on-device speech model for the active locale is present. Voice
/// only honors the airplane-mode promise once the model is installed; until then
/// a first recording would need a one-time download (network), so the UI surfaces
/// an explicit, consented preflight instead of fetching silently mid-capture.
public enum TranscriptionAssetReadiness: Sendable, Equatable {
    /// Model installed — voice works fully offline now.
    case installed
    /// Locale supported, but a one-time model download is needed first.
    case downloadable
    /// No on-device model for the user's language.
    case unsupported

    public var isInstalled: Bool {
        self == .installed
    }
}

/// Boundary for on-device ASR. The real engine wraps SpeechTranscriber on iOS 26;
/// tests and previews use the deterministic mock. Journaling never requires this
/// to exist — text entry is always a full citizen (product invariant #9).
public protocol TranscriptionEngine: Sendable {
    /// Provenance label recorded with each transcription.
    var engineKind: TranscriptionEngineKind { get }

    func availability() async -> TranscriptionAvailability

    /// Whether the model for the current locale is installed, downloadable, or
    /// unsupported — distinct from `availability()`, which only covers locale
    /// support and microphone permission.
    func assetReadiness() async -> TranscriptionAssetReadiness

    /// Downloads and installs the on-device model for the current locale. The
    /// only method permitted to touch the network, and only behind an explicit,
    /// consented preflight — `start()` must never download.
    func prepareAssets() async throws

    /// Starts capture and returns the live segment stream. The stream finishes
    /// after `stop()` has been called and the final segment has been delivered.
    /// Throws `.assetsNotInstalled` rather than downloading when the model is
    /// absent, so recording can never reach the network.
    func start() async throws -> AsyncThrowingStream<TranscriptSegment, Error>

    func stop() async
}

public extension TranscriptionEngine {
    /// Default for engines without downloadable assets (e.g. the mock): treat an
    /// available engine as installed and an unavailable one as unsupported.
    func assetReadiness() async -> TranscriptionAssetReadiness {
        await availability().isAvailable ? .installed : .unsupported
    }

    /// No-op for engines that carry no downloadable model.
    func prepareAssets() async throws {}
}

public enum TranscriptionEngineKind: String, Sendable {
    case speechTranscriber
    case whisper
    case mock
}
