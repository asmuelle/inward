import Foundation

/// One journal entry. Immutable value — edits produce a new value via `withEditedText`.
public struct Entry: Codable, Sendable, Hashable, Identifiable {
    public enum Source: String, Codable, Sendable {
        case voice
        case text
    }

    public let id: UUID
    public let createdAt: Date
    public let source: Source
    public let audioFileRef: String?
    public let transcriptRaw: String
    public let textEdited: String
    public let durationSec: Double?
    public let mood: String?
    public let locale: String

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        source: Source,
        audioFileRef: String? = nil,
        transcriptRaw: String,
        textEdited: String,
        durationSec: Double? = nil,
        mood: String? = nil,
        locale: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.audioFileRef = audioFileRef
        self.transcriptRaw = transcriptRaw
        self.textEdited = textEdited
        self.durationSec = durationSec
        self.mood = mood
        self.locale = locale
    }

    /// Returns a copy with the edited text replaced; the raw transcript is provenance
    /// and never changes.
    public func withEditedText(_ newText: String) -> Entry {
        Entry(
            id: id,
            createdAt: createdAt,
            source: source,
            audioFileRef: audioFileRef,
            transcriptRaw: transcriptRaw,
            textEdited: newText,
            durationSec: durationSec,
            mood: mood,
            locale: locale
        )
    }
}

/// Provenance for how an entry's transcript was produced (ASR quality debugging).
public struct Transcription: Codable, Sendable, Equatable {
    public enum Engine: String, Codable, Sendable {
        case speechTranscriber
        case whisper
        case mock
    }

    public let entryId: UUID
    public let engine: Engine
    public let confidence: Double
    public let completedAt: Date

    public init(entryId: UUID, engine: Engine, confidence: Double, completedAt: Date) {
        self.entryId = entryId
        self.engine = engine
        self.confidence = confidence
        self.completedAt = completedAt
    }
}
