import Foundation

/// The part of the local day an entry was written in. Deterministic calendar
/// arithmetic — no model, no inference — so rhythm lines stay in the same trust
/// register as `ThemeCount`: facts the user can verify against their own timeline.
public enum DayPart: String, Sendable, Equatable, CaseIterable {
    case morning
    case afternoon
    case evening
    case lateNight

    /// The day part of `date` in the entry's own captured zone. An invalid or
    /// missing identifier falls back to the reader's current zone — the best
    /// available truth for entries saved before the timezone stamp existed.
    public static func of(
        _ date: Date,
        timeZoneIdentifier: String?,
        calendar: Calendar = .current
    ) -> DayPart {
        var calendar = calendar
        if let identifier = timeZoneIdentifier, let zone = TimeZone(identifier: identifier) {
            calendar.timeZone = zone
        }
        switch calendar.component(.hour, from: date) {
        case 5 ... 11: return .morning
        case 12 ... 16: return .afternoon
        case 17 ... 21: return .evening
        default: return .lateNight // 22–23 and 0–4
        }
    }
}

/// The dominant writing time of a week: "`count` of `total` entries were written
/// in the `dayPart`". Counts, never interpretation — the observational register
/// the compliance posture allows.
public struct TimeRhythm: Sendable, Equatable {
    public let dayPart: DayPart
    public let count: Int
    public let total: Int

    public init(dayPart: DayPart, count: Int, total: Int) {
        self.dayPart = dayPart
        self.count = count
        self.total = total
    }
}

public extension WeeklyReviewPipeline {
    /// The week's dominant day part, or nil when there are fewer than two entries
    /// (a rhythm of one is noise, not a pattern). Ties break toward the earlier
    /// `DayPart` case so the result is stable across runs.
    static func timeRhythm(in context: WeekContext, calendar: Calendar = .current) -> TimeRhythm? {
        let total = context.entries.count
        guard total >= 2 else { return nil }

        var counts: [DayPart: Int] = [:]
        for entry in context.entries {
            let part = DayPart.of(entry.createdAt, timeZoneIdentifier: entry.timeZone, calendar: calendar)
            counts[part, default: 0] += 1
        }
        guard let dominant = DayPart.allCases.max(by: { counts[$0, default: 0] < counts[$1, default: 0] })
        else { return nil }
        return TimeRhythm(dayPart: dominant, count: counts[dominant, default: 0], total: total)
    }
}
