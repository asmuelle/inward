import Foundation
@testable import ReflectKit
import Testing

@Suite("Mock mind map provider — grounded by construction")
struct MockMindMapProviderTests {
    private func entry(_ days: Double, _ summary: String) -> ReviewableEntry {
        ReviewableEntry(id: UUID(), createdAt: Date(timeIntervalSince1970: days * 86400), summary: summary)
    }

    @Test("recurring words become branches whose leaves cite the entries they came from")
    func branchesFromRecurringThemes() async throws {
        let context = MindMapContext(entries: [
            entry(1, "Garden mornings felt lighter than the rest of the day."),
            entry(2, "Another garden afternoon; mornings still rushed though."),
            entry(3, "Deadline pressure stacked up across the whole week."),
        ])

        let draft = try await MockMindMapProvider().map(for: context)

        #expect(MindMapPipeline.isGrounded(draft, in: context))
        #expect(draft.branches.map(\.label).contains("garden"))
        for branch in draft.branches {
            #expect(!branch.leaves.isEmpty, "every mock branch carries a leaf per cited entry")
            #expect(Set(branch.leaves.flatMap(\.citedEntryIds)).isSubset(of: Set(branch.citedEntryIds)))
        }
    }

    @Test("with nothing recurring, each entry becomes its own branch so the map is never empty")
    func oneBranchPerEntryWhenNothingRecurs() async throws {
        let context = MindMapContext(entries: [
            entry(1, "Quiet evening by the river."),
            entry(2, "Loud workshop downtown."),
        ])

        let draft = try await MockMindMapProvider().map(for: context)

        #expect(draft.branches.count == 2)
        #expect(MindMapPipeline.isGrounded(draft, in: context))
    }

    @Test("the same month draws the same map")
    func isDeterministic() async throws {
        let context = MindMapContext(entries: [
            entry(1, "Garden mornings felt lighter."),
            entry(2, "Garden mornings again, lighter still."),
        ])

        let first = try await MockMindMapProvider().map(for: context)
        let second = try await MockMindMapProvider().map(for: context)

        #expect(first == second)
    }
}
