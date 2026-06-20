import Foundation

/// The minimal shape of an entry the weekly review is allowed to read and cite.
/// ReflectKit deliberately does not depend on JournalStore — the app maps its
/// `Entry` down to this value, so the review layer can never touch raw storage.
public struct ReviewableEntry: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    /// A short, precomputed summary of the entry (kept under the 8K window at save
    /// time). The review reasons over summaries, never the full transcript corpus.
    public let summary: String

    public init(id: UUID, createdAt: Date, summary: String) {
        self.id = id
        self.createdAt = createdAt
        self.summary = summary
    }
}

/// The week handed to the review: its start and the entries that may be cited.
/// Nothing outside `entries` is citable — that is what makes citations verifiable.
public struct WeekContext: Sendable, Equatable {
    public let weekStart: Date
    public let entries: [ReviewableEntry]

    public init(weekStart: Date, entries: [ReviewableEntry]) {
        self.weekStart = weekStart
        self.entries = entries
    }

    /// The set of ids a valid observation is allowed to reference.
    var citableIDs: Set<UUID> { Set(entries.map(\.id)) }
}

/// One gentle observation about a recurring theme, each pinned to at least one
/// real entry. `citedEntryIds` is the trust artifact: the UI renders these as
/// tappable links back to the user's own words.
public struct WeeklyObservation: Sendable, Equatable, Codable {
    public let theme: String
    public let note: String
    public let citedEntryIds: [UUID]

    public init(theme: String, note: String, citedEntryIds: [UUID]) {
        self.theme = theme
        self.note = note
        self.citedEntryIds = citedEntryIds
    }
}

/// Raw model output before validation. The pipeline decides whether it is shown,
/// regenerated, or replaced by the deterministic themes-only fallback.
public struct WeeklyReviewDraft: Sendable, Equatable, Codable {
    public let observations: [WeeklyObservation]

    public init(observations: [WeeklyObservation]) {
        self.observations = observations
    }
}

/// A recurring theme derived without any model: a word that appears across two or
/// more entries, with the real entries it came from. This is the floor the weekly
/// review degrades to when synthesis cannot be trusted — counts, never prose.
public struct ThemeCount: Sendable, Equatable, Codable {
    public let theme: String
    public let count: Int
    public let entryIds: [UUID]

    public init(theme: String, count: Int, entryIds: [UUID]) {
        self.theme = theme
        self.count = count
        self.entryIds = entryIds
    }
}

/// Boundary for weekly-review synthesis. The shipped implementation wraps Apple's
/// on-device FoundationModels; tests use the deterministic mock. As with
/// `ReflectionProviding`, no cloud implementation may ever exist (invariant #3).
public protocol WeeklyReviewProviding: Sendable {
    func availability() async -> ReflectionAvailability
    func review(for context: WeekContext) async throws -> WeeklyReviewDraft
}
