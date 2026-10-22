import Foundation

/// The Threads map: the mind map's drawn source, a month of entries as one
/// tree. Kept in its own extension so `Copy` stays under the type-length
/// limit; folded into `allStrings` through `threadsStrings`.
public extension Copy {
    // MARK: Mind map — sources

    static let mindMapSourceNames = Localized.t("mindMapSourceNames", "Names & places")
    static let mindMapSourceThreads = Localized.t("mindMapSourceThreads", "Threads")

    // MARK: Threads map

    static let mindMapThreadsIntro = Localized.t(
        "mindMapThreadsIntro",
        "The last 30 days as one map, drawn only from your own words."
    )
    static let mindMapThreadsDraw = Localized.t("mindMapThreadsDraw", "Draw the map")
    static let mindMapThreadsRedraw = Localized.t("mindMapThreadsRedraw", "Draw it again")
    static let mindMapThreadsDrawing = Localized.t("mindMapThreadsDrawing", "Drawing from your entries…")
    static let mindMapThreadsEmpty = Localized.t(
        "mindMapThreadsEmpty",
        "A few entries from the last month and there'll be a map to draw."
    )
    static let mindMapThreadsUnavailable = Localized.t(
        "mindMapThreadsUnavailable",
        "Drawing isn't ready on this phone yet."
    )
    /// The center of the deterministic fallback map, when nothing was drawn.
    static let mindMapThreadsCenterFallback = Localized.t("mindMapThreadsCenterFallback", "The last 30 days")
    static let mindMapThreadsThemesNote = Localized.t(
        "mindMapThreadsThemesNote",
        "Nothing was drawn this time — these are the words that kept coming back."
    )
    /// VoiceOver: the whole map as one phrase, so the center reads as a summary.
    static let mindMapThreadsCenterHint = Localized.t("mindMapThreadsCenterHint", "Opens every entry on the map")

    static let threadsStrings: [String] = [
        mindMapSourceNames,
        mindMapSourceThreads,
        mindMapThreadsIntro,
        mindMapThreadsDraw,
        mindMapThreadsRedraw,
        mindMapThreadsDrawing,
        mindMapThreadsEmpty,
        mindMapThreadsUnavailable,
        mindMapThreadsCenterFallback,
        mindMapThreadsThemesNote,
        mindMapThreadsCenterHint,
    ]
}
