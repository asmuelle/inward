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

@Suite("WeeklyReviewPrompting — fitting the week under a token budget")
struct WeeklyReviewBudgetingTests {
    private func context(_ summaries: [String]) -> WeekContext {
        let entries = summaries.enumerated().map { offset, summary in
            ReviewableEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(String(format: "%02X", offset + 1))")!,
                createdAt: Date(timeIntervalSince1970: 0),
                summary: summary
            )
        }
        return WeekContext(weekStart: Date(timeIntervalSince1970: 0), entries: entries)
    }

    @Test("a week that already fits is listed untouched")
    func fittingWeekUnchanged() {
        let week = context(["Garden mornings.", "Quiet evening."])

        let list = WeeklyReviewPrompting.entryList(for: week, tokenBudget: 1000)

        #expect(list == WeeklyReviewPrompting.entryList(for: week))
    }

    @Test("an oversized week trims every summary but keeps every entry and its number")
    func oversizedWeekTrimsPerEntry() {
        // Arrange — three entries, each ~150 tokens, against a 120-token budget
        let long = Array(repeating: "The kitchen still smelled like cardamom after everyone left.", count: 10)
            .joined(separator: " ")
        let week = context([long, long, long])

        // Act
        let list = WeeklyReviewPrompting.entryList(for: week, tokenBudget: 120)

        // Assert
        let lines = list.split(separator: "\n").map(String.init)
        #expect(lines.count == 3)
        #expect(lines[0].hasPrefix("[1] "))
        #expect(lines[1].hasPrefix("[2] "))
        #expect(lines[2].hasPrefix("[3] "))
        #expect(TokenBudgeter.estimateTokens(list) <= 120)
        for line in lines {
            #expect(!line.hasSuffix("[1] ") && line.count > 4, "no entry may be trimmed to nothing")
            #expect(long.hasPrefix(String(line.dropFirst(4))), "trimming keeps the opening of the summary")
        }
    }

    @Test("a tiny budget still leaves at least one word per entry")
    func tinyBudgetKeepsSomething() {
        let week = context(["Garden mornings again and again.", "Rushed mornings."])

        let list = WeeklyReviewPrompting.entryList(for: week, tokenBudget: 1)

        let lines = list.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.count > 4 })
    }
}
