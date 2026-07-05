import Foundation
@testable import Inward
import Testing

@Suite("Weekly reminder — fire-time mapping")
struct WeeklyReviewReminderTests {
    @Test("weekday and minutes map to a repeating local fire time")
    func mapsWeekdayAndMinutes() {
        // Sunday (1) at 8:15 PM
        let components = WeeklyReviewReminder.fireComponents(weekday: 1, minutesOfDay: 20 * 60 + 15)

        #expect(components.weekday == 1)
        #expect(components.hour == 20)
        #expect(components.minute == 15)
    }

    @Test("out-of-range inputs clamp instead of producing an impossible trigger")
    func clampsOutOfRange() {
        let low = WeeklyReviewReminder.fireComponents(weekday: 0, minutesOfDay: -10)
        let high = WeeklyReviewReminder.fireComponents(weekday: 9, minutesOfDay: 25 * 60)

        #expect(low.weekday == 1)
        #expect(low.hour == 0)
        #expect(low.minute == 0)
        #expect(high.weekday == 7)
        #expect(high.hour == 23)
        #expect(high.minute == 59)
    }
}
