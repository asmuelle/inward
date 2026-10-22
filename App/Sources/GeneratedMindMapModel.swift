import Foundation
import JournalStore
import ReflectKit
import SafetyKit

/// Assembles the last month from the store, runs it through the verified-
/// citation map pipeline, and keeps an id→entry lookup so every node opens the
/// entries it came from. Draws only when asked — a map is a deliberate act,
/// not something that runs on every visit. Read-only; never writes.
@MainActor
@Observable
final class GeneratedMindMapModel {
    enum State: Equatable {
        case idle
        case drawing
        case drawn(MindMapOutcome)
    }

    /// The stretch of entries one map covers.
    static let windowDays = 30

    private(set) var state: State = .idle
    private(set) var entriesByID: [UUID: Entry] = [:]

    private let store: any JournalStoring
    private let provider: any MindMapProviding
    /// Fixed in tests; nil means "now, at the moment of drawing".
    private let referenceDate: Date?
    private let calendar: Calendar

    init(
        store: any JournalStoring,
        provider: any MindMapProviding,
        synthesisAllowed: Bool = true,
        referenceDate: Date? = nil,
        calendar: Calendar = .current
    ) {
        self.store = store
        // Drawing is Pro; without it the provider reports unavailable and the
        // map degrades to deterministic theme counts — the crisis gate still
        // runs first, unchanged.
        self.provider = synthesisAllowed ? provider : SynthesisWithheldMapProvider()
        self.referenceDate = referenceDate
        self.calendar = calendar
    }

    var hasEntries: Bool {
        !entriesByID.isEmpty
    }

    /// Draws the last month. Entries are handed over newest first so the
    /// pipeline's token budget keeps the recent ones when the month is long.
    func draw() async {
        state = .drawing
        let entries: [Entry]
        do {
            entries = try await store.allEntries()
        } catch {
            state = .drawn(.unavailable)
            return
        }

        let now = referenceDate ?? Date()
        let start = calendar.date(byAdding: .day, value: -Self.windowDays, to: now) ?? now
        let recent = entries
            .filter { $0.createdAt >= start }
            .sorted { $0.createdAt > $1.createdAt }
        entriesByID = Dictionary(recent.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let context = MindMapContext(entries: recent.map(WeeklyReviewModel.reviewable))
        let outcome = await MindMapPipeline(
            gate: CrisisGate(localizedFor: .current),
            provider: provider
        ).map(for: context)
        state = .drawn(outcome)
    }

    func entry(for id: UUID) -> Entry? {
        entriesByID[id]
    }

    /// The entries behind one node, newest first, skipping any id that no
    /// longer resolves (an entry deleted since the map was drawn).
    func entries(for ids: [UUID]) -> [Entry] {
        ids.compactMap { entriesByID[$0] }.sorted { $0.createdAt > $1.createdAt }
    }
}

/// Stands in for the map provider when the entitlement doesn't cover it:
/// always unavailable, so the pipeline (crisis gate included) degrades to the
/// deterministic themes-only outcome without a second code path.
private struct SynthesisWithheldMapProvider: MindMapProviding {
    func availability() async -> ReflectionAvailability {
        .unavailable(reason: "drawing is part of Inward Pro")
    }

    func map(for _: MindMapContext) async throws -> MindMapDraft {
        throw ReflectionError.modelUnavailable
    }
}
