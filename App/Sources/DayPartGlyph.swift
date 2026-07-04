import ReflectKit

/// SF Symbol for each part of the local day — shared by the timeline rows and
/// the weekly-review rhythm line so the same moment always wears the same mark.
enum DayPartGlyph {
    static func symbolName(for part: DayPart) -> String {
        switch part {
        case .morning: "sunrise"
        case .afternoon: "sun.max"
        case .evening: "sunset"
        case .lateNight: "moon.stars"
        }
    }
}
