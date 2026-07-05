import Foundation
import JournalStore

/// Echoes, phase 1: purely deterministic "on this day" resurfacing — the same
/// calendar day a month or a year (or several) ago. No model anywhere; the card
/// is a dated pointer at the user's own words, and a dismissed entry never
/// comes back (resurfacing a hard anniversary uninvited costs more than the
/// feature earns).
public enum OnThisDay {
    /// The entry to resurface today, or nil. Year anniversaries outrank
    /// month-ago echoes; within a rank the most recent entry wins, with ties
    /// broken on UUID string so the pick is stable across launches.
    public static func echo(
        from entries: [Entry],
        today: Date,
        calendar: Calendar = .current,
        excluding: Set<UUID> = []
    ) -> Entry? {
        let now = calendar.dateComponents([.year, .month, .day], from: today)
        guard let todayYear = now.year, let todayMonth = now.month, let todayDay = now.day else { return nil }

        let candidates = entries.compactMap { entry -> (entry: Entry, isYearEcho: Bool)? in
            guard !excluding.contains(entry.id), entry.createdAt < today else { return nil }
            // The writer's own day: an entry kept at 23:30 in Tokyo belongs to
            // Tokyo's date, wherever the reader is now.
            var entryCalendar = calendar
            if let zone = entry.timeZone.flatMap(TimeZone.init(identifier:)) {
                entryCalendar.timeZone = zone
            }
            let written = entryCalendar.dateComponents([.year, .month, .day], from: entry.createdAt)
            guard written.day == todayDay, let year = written.year, let month = written.month else { return nil }

            if year < todayYear {
                return (entry, true)
            }
            if year == todayYear, month < todayMonth {
                return (entry, false)
            }
            return nil
        }

        return candidates.max { lhs, rhs in
            if lhs.isYearEcho != rhs.isYearEcho { return rhs.isYearEcho }
            if lhs.entry.createdAt != rhs.entry.createdAt { return lhs.entry.createdAt < rhs.entry.createdAt }
            return lhs.entry.id.uuidString > rhs.entry.id.uuidString
        }?.entry
    }
}
