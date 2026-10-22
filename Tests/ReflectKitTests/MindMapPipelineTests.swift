import Foundation
@testable import ReflectKit
import SafetyKit
import Testing

// MARK: - Fixtures

private enum Month {
    static let idA = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    static let idB = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
    static let idC = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!
    static let foreign = UUID(uuidString: "00000000-0000-0000-0000-0000000000F9")!

    static func entry(_ id: UUID, _ offsetDays: Double, _ summary: String) -> ReviewableEntry {
        ReviewableEntry(id: id, createdAt: Date(timeIntervalSince1970: offsetDays * 86400), summary: summary)
    }

    static let entries = [
        entry(idA, 3, "Garden mornings felt lighter than the rest of the day."),
        entry(idB, 2, "Another garden afternoon; mornings still rushed though."),
        entry(idC, 1, "Deadline pressure stacked up across the whole week."),
    ]

    static let context = MindMapContext(entries: entries)

    static let crisis = MindMapContext(entries: [
        entry(idA, 1, "Garden mornings felt lighter."),
        entry(idB, 2, "Some days I think about how to end my life."),
    ])

    static let grounded = MindMapDraft(
        center: "A month of mornings",
        branches: [
            MindMapBranch(
                label: "the garden",
                citedEntryIds: [idA, idB],
                leaves: [MindMapLeaf(label: "lighter mornings", citedEntryIds: [idA])]
            ),
            MindMapBranch(label: "deadline pressure", citedEntryIds: [idC], leaves: []),
        ]
    )

    static let foreignCitation = MindMapDraft(
        center: "A month of mornings",
        branches: [MindMapBranch(label: "the garden", citedEntryIds: [foreign], leaves: [])]
    )
}

/// Counts calls and replays a scripted list of results so regeneration is observable.
private actor ScriptedProvider: MindMapProviding {
    private(set) var invocations = 0
    private(set) var lastContext: MindMapContext?
    private let results: [Result<MindMapDraft, ReflectionError>]
    private let availabilityValue: ReflectionAvailability

    init(_ results: [Result<MindMapDraft, ReflectionError>], availability: ReflectionAvailability = .available) {
        self.results = results
        availabilityValue = availability
    }

    func availability() async -> ReflectionAvailability {
        availabilityValue
    }

    func map(for context: MindMapContext) async throws -> MindMapDraft {
        lastContext = context
        defer { invocations += 1 }
        guard invocations < results.count else { throw ReflectionError.generationFailed("exhausted") }
        return try results[invocations].get()
    }
}

// MARK: - Tests

@Suite("Mind map pipeline — gate, grounding, regeneration, floor")
struct MindMapPipelineTests {
    @Test("a crisis match anywhere in the entries suppresses the model and returns resources")
    func crisisSuppressesModel() async {
        let provider = ScriptedProvider([.success(Month.grounded)])
        let pipeline = MindMapPipeline(provider: provider)

        let outcome = await pipeline.map(for: Month.crisis)

        guard case let .suppressed(resources) = outcome else {
            Issue.record("expected suppression, got \(outcome)")
            return
        }
        #expect(!resources.isEmpty)
        #expect(await provider.invocations == 0, "the model must never run during a crisis")
    }

    @Test("a grounded draft is drawn as-is")
    func groundedDraftIsDrawn() async {
        let provider = ScriptedProvider([.success(Month.grounded)])

        let outcome = await MindMapPipeline(provider: provider).map(for: Month.context)

        #expect(outcome == .drawn(Month.grounded))
        #expect(await provider.invocations == 1)
    }

    @Test("a draft citing an entry outside the month is regenerated once, then kept if grounded")
    func foreignCitationRegeneratesOnce() async {
        let provider = ScriptedProvider([.success(Month.foreignCitation), .success(Month.grounded)])

        let outcome = await MindMapPipeline(provider: provider).map(for: Month.context)

        #expect(outcome == .drawn(Month.grounded))
        #expect(await provider.invocations == 2)
    }

    @Test("two ungrounded drafts fall to deterministic themes, never to the prose")
    func twoFailuresFallToThemes() async {
        let provider = ScriptedProvider([.success(Month.foreignCitation), .failure(.generationFailed("boom"))])

        let outcome = await MindMapPipeline(provider: provider).map(for: Month.context)

        guard case let .themesOnly(themes) = outcome else {
            Issue.record("expected themes-only, got \(outcome)")
            return
        }
        #expect(themes.map(\.theme).contains("garden"))
        #expect(await provider.invocations == 2)
    }

    @Test("an unavailable model falls straight to deterministic themes without a call")
    func unavailableModelFallsToThemes() async {
        let provider = ScriptedProvider([.success(Month.grounded)], availability: .unavailable(reason: "off"))

        let outcome = await MindMapPipeline(provider: provider).map(for: Month.context)

        guard case .themesOnly = outcome else {
            Issue.record("expected themes-only, got \(outcome)")
            return
        }
        #expect(await provider.invocations == 0)
    }

    @Test("no entries is unavailable, with no model call and no gate pass")
    func emptyMonthIsUnavailable() async {
        let provider = ScriptedProvider([.success(Month.grounded)])

        let outcome = await MindMapPipeline(provider: provider).map(for: MindMapContext(entries: []))

        #expect(outcome == .unavailable)
        #expect(await provider.invocations == 0)
    }

    @Test("the provider sees only the entries that fit the token budget, leading entries first")
    func providerSeesBudgetedEntries() async {
        let long = String(repeating: "word ", count: 6000)
        let context = MindMapContext(entries: [
            Month.entry(Month.idA, 1, "A short first entry about the garden."),
            Month.entry(Month.idB, 2, long),
            Month.entry(Month.idC, 3, "A short third entry about the garden."),
        ])
        let provider = ScriptedProvider([.success(MindMapDraft(
            center: "garden",
            branches: [MindMapBranch(label: "garden", citedEntryIds: [Month.idA], leaves: [])]
        ))])

        _ = await MindMapPipeline(provider: provider).map(for: context)

        let seen = await provider.lastContext?.entries.map(\.id)
        #expect(seen == [Month.idA], "budgeting stops at the first entry that does not fit")
    }

    // MARK: Grounding rules

    @Test("grounding rejects an empty center, an empty branch label, or no branches")
    func rejectsEmptyShapes() {
        let branch = MindMapBranch(label: "garden", citedEntryIds: [Month.idA], leaves: [])
        #expect(!MindMapPipeline.isGrounded(MindMapDraft(center: " ", branches: [branch]), in: Month.context))
        #expect(!MindMapPipeline.isGrounded(MindMapDraft(center: "ok", branches: []), in: Month.context))
        let blank = MindMapBranch(label: "", citedEntryIds: [Month.idA], leaves: [])
        #expect(!MindMapPipeline.isGrounded(MindMapDraft(center: "ok", branches: [blank]), in: Month.context))
    }

    @Test("grounding rejects a branch or leaf with no real citation")
    func rejectsUncitedNodes() {
        let uncited = MindMapBranch(label: "garden", citedEntryIds: [], leaves: [])
        #expect(!MindMapPipeline.isGrounded(MindMapDraft(center: "ok", branches: [uncited]), in: Month.context))
        let uncitedLeaf = MindMapBranch(
            label: "garden",
            citedEntryIds: [Month.idA],
            leaves: [MindMapLeaf(label: "mornings", citedEntryIds: [])]
        )
        #expect(!MindMapPipeline.isGrounded(MindMapDraft(center: "ok", branches: [uncitedLeaf]), in: Month.context))
    }

    @Test("grounding rejects regulated vocabulary in any label")
    func rejectsBannedTerms() {
        let term = BannedTerms.lexicon[0]
        let tainted = MindMapBranch(label: "about \(term)", citedEntryIds: [Month.idA], leaves: [])
        #expect(!MindMapPipeline.isGrounded(MindMapDraft(center: "ok", branches: [tainted]), in: Month.context))
        #expect(!MindMapPipeline.isGrounded(
            MindMapDraft(center: term, branches: [MindMapBranch(label: "garden", citedEntryIds: [Month.idA], leaves: [])]),
            in: Month.context
        ))
    }

    @Test("grounding caps the map at the branch, leaf, and label limits")
    func rejectsOversizedMaps() {
        let branch = MindMapBranch(label: "garden", citedEntryIds: [Month.idA], leaves: [])
        let tooMany = Array(repeating: branch, count: MindMapPipeline.maxBranches + 1)
        #expect(!MindMapPipeline.isGrounded(MindMapDraft(center: "ok", branches: tooMany), in: Month.context))

        let leaf = MindMapLeaf(label: "mornings", citedEntryIds: [Month.idA])
        let bushy = MindMapBranch(
            label: "garden",
            citedEntryIds: [Month.idA],
            leaves: Array(repeating: leaf, count: MindMapPipeline.maxLeavesPerBranch + 1)
        )
        #expect(!MindMapPipeline.isGrounded(MindMapDraft(center: "ok", branches: [bushy]), in: Month.context))

        let longLabel = String(repeating: "a", count: MindMapPipeline.maxLabelCharacters + 1)
        let verbose = MindMapBranch(label: longLabel, citedEntryIds: [Month.idA], leaves: [])
        #expect(!MindMapPipeline.isGrounded(MindMapDraft(center: "ok", branches: [verbose]), in: Month.context))
    }

    @Test("a draft's cited ids are the union of its branches and leaves, in order, without duplicates")
    func allCitedEntryIds() {
        #expect(Month.grounded.allCitedEntryIds == [Month.idA, Month.idB, Month.idC])
    }
}
