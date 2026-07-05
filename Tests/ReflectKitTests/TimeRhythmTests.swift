import Foundation
@testable import ReflectKit
import Testing

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func date(hourUTC: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = 15
    components.hour = hourUTC
    return utcCalendar().date(from: components)!
}

private func entry(hourUTC: Int, timeZone: String? = nil) -> ReviewableEntry {
    ReviewableEntry(id: UUID(), createdAt: date(hourUTC: hourUTC), summary: "a line", timeZone: timeZone)
}

@Suite("TimeRhythm — deterministic day-part facts")
struct TimeRhythmTests {
    @Test("hours bucket into the expected day parts", arguments: [
        (5, DayPart.morning), (11, DayPart.morning),
        (12, DayPart.afternoon), (16, DayPart.afternoon),
        (17, DayPart.evening), (21, DayPart.evening),
        (22, DayPart.lateNight), (23, DayPart.lateNight),
        (0, DayPart.lateNight), (4, DayPart.lateNight),
    ])
    func dayPartBuckets(_ pair: (Int, DayPart)) {
        #expect(DayPart.of(date(hourUTC: pair.0), timeZoneIdentifier: nil, calendar: utcCalendar()) == pair.1)
    }

    @Test("an entry's own captured zone decides its day part")
    func honorsCapturedZone() {
        // 23:00 UTC is 08:00 the next morning in Tokyo — a traveler's late-UTC
        // entry must not read as late night.
        let part = DayPart.of(date(hourUTC: 23), timeZoneIdentifier: "Asia/Tokyo", calendar: utcCalendar())

        #expect(part == .morning)
    }

    @Test("an unknown identifier falls back to the calendar's zone")
    func invalidZoneFallsBack() {
        let part = DayPart.of(date(hourUTC: 9), timeZoneIdentifier: "Not/AZone", calendar: utcCalendar())

        #expect(part == .morning)
    }

    @Test("the dominant day part wins, with its count and the week's total")
    func dominantRhythm() {
        // Arrange
        let context = WeekContext(weekStart: date(hourUTC: 0), entries: [
            entry(hourUTC: 22), entry(hourUTC: 23), entry(hourUTC: 9),
        ])

        // Act
        let rhythm = WeeklyReviewPipeline.timeRhythm(in: context, calendar: utcCalendar())

        // Assert
        #expect(rhythm == TimeRhythm(dayPart: .lateNight, count: 2, total: 3))
    }

    @Test("fewer than two entries yields no rhythm — one entry is not a pattern")
    func tooFewEntries() {
        let context = WeekContext(weekStart: date(hourUTC: 0), entries: [entry(hourUTC: 9)])

        #expect(WeeklyReviewPipeline.timeRhythm(in: context, calendar: utcCalendar()) == nil)
    }

    @Test("ties break toward the earlier day part so the line is stable")
    func tieBreaksTowardEarlierPart() {
        let context = WeekContext(weekStart: date(hourUTC: 0), entries: [
            entry(hourUTC: 20), entry(hourUTC: 9),
        ])

        let rhythm = WeeklyReviewPipeline.timeRhythm(in: context, calendar: utcCalendar())

        #expect(rhythm == TimeRhythm(dayPart: .morning, count: 1, total: 2))
    }
}
