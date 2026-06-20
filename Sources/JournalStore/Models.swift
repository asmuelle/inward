import Foundation

/// Produces the short, stored summary of an entry. Precomputed once at save so the
/// weekly review reasons over summaries (staying under the model's 8K window)
/// instead of re-reading every full entry. Deterministic and model-optional
/// (invariant #9); an on-device model can populate the same field later.
public enum EntrySummary {
    public static let maxLength = 160

    public static func make(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if let end = trimmed.firstIndex(where: { ".!?".contains($0) }) {
            let sentence = String(trimmed[...end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count >= 8 { return sentence }
        }
        return String(trimmed.prefix(maxLength))
    }
}

/// One journal entry. Immutable value — edits produce a new value via `withEditedText`.
public struct Entry: Sendable, Hashable, Identifiable {
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
    /// Short summary, derived from `textEdited` at save and persisted.
    public let summary: String
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
        summary: String? = nil,
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
        self.summary = summary ?? EntrySummary.make(from: textEdited)
        self.durationSec = durationSec
        self.mood = mood
        self.locale = locale
    }

    /// Returns a copy with the edited text replaced; the summary is recomputed and
    /// the raw transcript is provenance, so it never changes.
    public func withEditedText(_ newText: String) -> Entry {
        Entry(
            id: id,
            createdAt: createdAt,
            source: source,
            audioFileRef: audioFileRef,
            transcriptRaw: transcriptRaw,
            textEdited: newText,
            summary: nil,
            durationSec: durationSec,
            mood: mood,
            locale: locale
        )
    }
}

extension Entry: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, createdAt, source, audioFileRef, transcriptRaw, textEdited, summary, durationSec, mood, locale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let textEdited = try container.decode(String.self, forKey: .textEdited)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            source: try container.decode(Source.self, forKey: .source),
            audioFileRef: try container.decodeIfPresent(String.self, forKey: .audioFileRef),
            transcriptRaw: try container.decode(String.self, forKey: .transcriptRaw),
            textEdited: textEdited,
            // Tolerate archives written before summaries existed.
            summary: try container.decodeIfPresent(String.self, forKey: .summary) ?? EntrySummary.make(from: textEdited),
            durationSec: try container.decodeIfPresent(Double.self, forKey: .durationSec),
            mood: try container.decodeIfPresent(String.self, forKey: .mood),
            locale: try container.decode(String.self, forKey: .locale)
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
