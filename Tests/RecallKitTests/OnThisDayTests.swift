import Foundation
import JournalStore
@testable import RecallKit
import Testing

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10) -> Date {
    utcCalendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

private func entry(at createdAt: Date, timeZone: String? = nil, id: UUID = UUID()) -> Entry {
    Entry(
        id: id,
        createdAt: createdAt,
        source: .text,
        transcriptRaw: "words",
        textEdited: "words",
        locale: "en_US",
        timeZone: timeZone
    )
}

@Suite("OnThisDay — deterministic echo selection")
struct OnThisDayTests {
    private let today = date(2026, 7, 4)

    @Test("an entry from the same day a year ago echoes")
    func yearEcho() {
        let anniversary = entry(at: date(2025, 7, 4))
        let unrelated = entry(at: date(2026, 6, 20))

        let echo = OnThisDay.echo(from: [anniversary, unrelated], today: today, calendar: utcCalendar())

        #expect(echo == anniversary)
    }

    @Test("an entry from the same day-of-month a month ago echoes")
    func monthEcho() {
        let monthAgo = entry(at: date(2026, 6, 4))

        let echo = OnThisDay.echo(from: [monthAgo], today: today, calendar: utcCalendar())

        #expect(echo == monthAgo)
    }

    @Test("a year anniversary outranks a month-ago echo")
    func yearBeatsMonth() {
        let monthAgo = entry(at: date(2026, 6, 4))
        let yearAgo = entry(at: date(2024, 7, 4))

        let echo = OnThisDay.echo(from: [monthAgo, yearAgo], today: today, calendar: utcCalendar())

        #expect(echo == yearAgo)
    }

    @Test("dismissed entries never resurface")
    func honorsDismissals() {
        let anniversary = entry(at: date(2025, 7, 4))

        let echo = OnThisDay.echo(
            from: [anniversary],
            today: today,
            calendar: utcCalendar(),
            excluding: [anniversary.id]
        )

        #expect(echo == nil)
    }

    @Test("the writer's own timezone decides which day an entry belongs to")
    func honorsCapturedZone() {
        // 23:30 UTC on July 3rd 2025 was already July 4th in Tokyo — for its
        // writer this is an anniversary entry.
        let tokyoNight = entry(at: date(2025, 7, 3, hour: 23), timeZone: "Asia/Tokyo")

        let echo = OnThisDay.echo(from: [tokyoNight], today: today, calendar: utcCalendar())

        #expect(echo == tokyoNight)
    }

    @Test("entries from today or other days stay quiet")
    func noEchoWithoutAnniversary() {
        let earlierToday = entry(at: date(2026, 7, 4, hour: 6))
        let otherDay = entry(at: date(2025, 7, 5))

        let echo = OnThisDay.echo(from: [earlierToday, otherDay], today: today, calendar: utcCalendar())

        #expect(echo == nil)
    }
}
