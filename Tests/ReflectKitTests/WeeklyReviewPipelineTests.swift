import Foundation
@testable import ReflectKit
import SafetyKit
import Testing

// MARK: - Fixtures

private enum Week {
    // Stable ids and dates — determinism is the whole point of the trust layer.
    static let idA = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    static let idB = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
    static let idC = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!

    static func entry(_ id: UUID, _ offsetDays: Double, _ summary: String) -> ReviewableEntry {
        ReviewableEntry(id: id, createdAt: Date(timeIntervalSince1970: offsetDays * 86_400), summary: summary)
    }

    /// "garden" and "mornings" each recur across entries A and B; C is unrelated.
    static let context = WeekContext(
        weekStart: Date(timeIntervalSince1970: 0),
        entries: [
            entry(idA, 1, "Garden mornings felt lighter than the rest of the day."),
            entry(idB, 2, "Another garden afternoon; mornings still rushed though."),
            entry(idC, 3, "Deadline pressure stacked up across the whole week."),
        ]
    )

    static let crisisContext = WeekContext(
        weekStart: Date(timeIntervalSince1970: 0),
        entries: [
            entry(idA, 1, "Garden mornings felt lighter."),
            entry(idB, 2, "Some days I think about how to end my life."),
        ]
    )
}

/// Counts calls and replays a scripted list of results so regeneration is observable.
private actor ScriptedProvider: WeeklyReviewProviding {
    private(set) var invocations = 0
    private let results: [Result<WeeklyReviewDraft, ReflectionError>]
    private let availabilityValue: ReflectionAvailability

    init(_ results: [Result<WeeklyReviewDraft, ReflectionError>], availability: ReflectionAvailability = .available) {
        self.results = results
        availabilityValue = availability
    }

    nonisolated func availability() async -> ReflectionAvailability { availabilityValue }

    func review(for _: WeekContext) async throws -> WeeklyReviewDraft {
        defer { invocations += 1 }
        switch results[min(invocations, results.count - 1)] {
        case let .success(draft): return draft
        case let .failure(error): throw error
        }
    }
}

private func grounded() -> WeeklyReviewDraft {
    WeeklyReviewDraft(observations: [
        WeeklyObservation(theme: "garden", note: "The garden kept showing up.", citedEntryIds: [Week.idA, Week.idB]),
    ])
}

private func fabricated() -> WeeklyReviewDraft {
    WeeklyReviewDraft(observations: [
        WeeklyObservation(theme: "garden", note: "A claim about an entry that does not exist.", citedEntryIds: [UUID()]),
    ])
}

// MARK: - Tests

@Suite("WeeklyReviewPipeline — gate before model, citations verified after")
struct WeeklyReviewPipelineTests {
    @Test("crisis content in the week suppresses synthesis; the model is never called")
    func crisisSuppressesModel() async {
        let provider = ScriptedProvider([.success(grounded())])
        let pipeline = WeeklyReviewPipeline(provider: provider)

        let outcome = await pipeline.review(for: Week.crisisContext)

        guard case let .suppressed(resources) = outcome else {
            Issue.record("expected suppression, got \(outcome)")
            return
        }
        #expect(resources == SupportResource.bundled)
        #expect(await provider.invocations == 0, "the model must never see a week containing crisis text")
    }

    @Test("a grounded draft is shown as-is")
    func groundedDraftSynthesized() async {
        let pipeline = WeeklyReviewPipeline(provider: ScriptedProvider([.success(grounded())]))

        let outcome = await pipeline.review(for: Week.context)

        #expect(outcome == .synthesized(grounded()))
    }

    @Test("the deterministic mock provider is grounded by construction")
    func mockProviderIsGrounded() async {
        let pipeline = WeeklyReviewPipeline(provider: MockWeeklyReviewProvider())

        let outcome = await pipeline.review(for: Week.context)

        guard case let .synthesized(draft) = outcome else {
            Issue.record("expected synthesis, got \(outcome)")
            return
        }
        #expect(!draft.observations.isEmpty)
        #expect(draft.observations.allSatisfy { !$0.citedEntryIds.isEmpty })
    }

    @Test("an ungrounded draft is regenerated once, then accepted when the retry is clean")
    func regeneratesOnceThenSucceeds() async {
        let provider = ScriptedProvider([.success(fabricated()), .success(grounded())])
        let pipeline = WeeklyReviewPipeline(provider: provider)

        let outcome = await pipeline.review(for: Week.context)

        #expect(outcome == .synthesized(grounded()))
        #expect(await provider.invocations == 2, "exactly one regeneration")
    }

    @Test("two fabricated drafts fall back to deterministic theme counts that cite real entries")
    func twoFabricationsFallBackToThemes() async {
        let provider = ScriptedProvider([.success(fabricated()), .success(fabricated())])
        let pipeline = WeeklyReviewPipeline(provider: provider)

        let outcome = await pipeline.review(for: Week.context)

        guard case let .themesOnly(themes) = outcome else {
            Issue.record("expected themes-only fallback, got \(outcome)")
            return
        }
        #expect(await provider.invocations == 2)
        #expect(!themes.isEmpty)
        let citable = Week.context.citableIDs
        #expect(themes.allSatisfy { !$0.entryIds.isEmpty && $0.entryIds.allSatisfy(citable.contains) })
        #expect(themes.contains { $0.theme == "garden" })
    }

    @Test("regulated vocabulary in an observation is never shown; it falls back to themes")
    func bannedVocabularyFallsBack() async {
        let tainted = WeeklyReviewDraft(observations: [
            WeeklyObservation(theme: "habits", note: "This reads like therapy for your week.", citedEntryIds: [Week.idA]),
        ])
        let pipeline = WeeklyReviewPipeline(provider: ScriptedProvider([.success(tainted), .success(tainted)]))

        let outcome = await pipeline.review(for: Week.context)

        guard case .themesOnly = outcome else {
            Issue.record("regulated vocabulary must never surface; got \(outcome)")
            return
        }
    }

    @Test("an observation with no citations is rejected")
    func uncitedObservationRejected() {
        let uncited = WeeklyReviewDraft(observations: [
            WeeklyObservation(theme: "garden", note: "No source for this.", citedEntryIds: []),
        ])
        #expect(!WeeklyReviewPipeline.isGrounded(uncited, in: Week.context))
    }

    @Test("a citation to a non-existent entry is rejected")
    func fabricatedCitationRejected() {
        #expect(!WeeklyReviewPipeline.isGrounded(fabricated(), in: Week.context))
        #expect(WeeklyReviewPipeline.isGrounded(grounded(), in: Week.context))
    }

    @Test("an empty week is a quiet no-review; the model is never called")
    func emptyWeekIsUnavailable() async {
        let provider = ScriptedProvider([.success(grounded())])
        let pipeline = WeeklyReviewPipeline(provider: provider)

        let outcome = await pipeline.review(for: WeekContext(weekStart: Date(timeIntervalSince1970: 0), entries: []))

        #expect(outcome == .unavailable)
        #expect(await provider.invocations == 0)
    }

    @Test("model-optional: an unavailable provider is a quiet no-review state")
    func unavailableProviderIsUnavailable() async {
        let provider = ScriptedProvider([.success(grounded())], availability: .unavailable(reason: "no apple intelligence"))
        let pipeline = WeeklyReviewPipeline(provider: provider)

        let outcome = await pipeline.review(for: Week.context)

        #expect(outcome == .unavailable)
        #expect(await provider.invocations == 0)
    }

    @Test("a throwing provider degrades to themes, never to raw or fabricated text")
    func throwingProviderFallsBack() async {
        let provider = ScriptedProvider(
            [.failure(.generationFailed("a")), .failure(.generationFailed("b"))]
        )
        let pipeline = WeeklyReviewPipeline(provider: provider)

        let outcome = await pipeline.review(for: Week.context)

        guard case .themesOnly = outcome else {
            Issue.record("expected themes-only fallback, got \(outcome)")
            return
        }
        #expect(await provider.invocations == 2)
    }

    @Test("recurring themes cite only real entries and surface the shared words")
    func recurringThemesAreGrounded() {
        let themes = WeeklyReviewPipeline.recurringThemes(in: Week.context)

        #expect(!themes.isEmpty)
        #expect(themes.contains { $0.theme == "garden" })
        #expect(themes.contains { $0.theme == "mornings" })
        let citable = Week.context.citableIDs
        #expect(themes.allSatisfy { $0.count >= 2 && $0.entryIds.allSatisfy(citable.contains) })
        // "deadline"/"pressure" appear in only one entry and must not be themes.
        #expect(!themes.contains { $0.theme == "deadline" })
    }
}
