import Foundation
@testable import ReflectKit
import Testing

private func entry(_ tail: String, _ summary: String) -> ReviewableEntry {
    ReviewableEntry(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(tail)")!,
        createdAt: Date(timeIntervalSince1970: 0),
        summary: summary
    )
}

@Suite("WeeklyReviewPrompting — numbering and citation resolution")
struct WeeklyReviewPromptingTests {
    private let entries = [
        entry("A1", "Garden mornings."),
        entry("B2", "Rushed mornings."),
        entry("C3", "Quiet evening."),
    ]

    @Test("entries are listed with stable 1-based numbers, in order")
    func entryListIsNumbered() {
        let context = WeekContext(weekStart: Date(timeIntervalSince1970: 0), entries: entries)

        let list = WeeklyReviewPrompting.entryList(for: context)

        #expect(list == "[1] Garden mornings.\n[2] Rushed mornings.\n[3] Quiet evening.")
    }

    @Test("valid numbers resolve to the matching entry ids, preserving order")
    func resolvesValidNumbers() {
        let ids = WeeklyReviewPrompting.resolve(numbers: [3, 1], in: entries)

        #expect(ids == [entries[2].id, entries[0].id])
    }

    @Test("out-of-range and non-positive numbers are dropped — no fabricated citations")
    func dropsOutOfRange() {
        let ids = WeeklyReviewPrompting.resolve(numbers: [0, -1, 4, 99, 2], in: entries)

        #expect(ids == [entries[1].id], "only the in-range number 2 survives")
    }

    @Test("duplicate numbers collapse to one id, first occurrence wins")
    func dedupesNumbers() {
        let ids = WeeklyReviewPrompting.resolve(numbers: [1, 1, 2, 1], in: entries)

        #expect(ids == [entries[0].id, entries[1].id])
    }

    @Test("an empty citation list resolves to nothing")
    func emptyResolvesEmpty() {
        #expect(WeeklyReviewPrompting.resolve(numbers: [], in: entries).isEmpty)
    }
}
