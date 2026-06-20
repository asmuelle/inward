import Foundation

/// Every user-facing string in the M1 slice lives here, in the Lamplight voice:
/// quiet, second-person, never instructive. The compliance suite scans `allStrings`
/// against the banned-terms lexicon on every run — keep new copy in this file.
public enum Copy {
    public static let appName = "Inward"

    // MARK: Timeline

    public static let timelineTitle = "Inward"
    public static let timelineEmpty = "Nothing here yet. When you're ready, speak — your words stay on this phone."
    public static let spokenLabel = "Spoken"
    public static let writtenLabel = "Written"

    // MARK: Capture

    public static let recordAccessibility = "Start recording"
    public static let stopAccessibility = "Stop recording"
    public static let listening = "Listening…"
    public static let readItBack = "Read it back"
    public static let keepEntry = "Keep this entry"
    public static let discardEntry = "Discard"
    public static let writeInstead = "Write instead"
    public static let writePlaceholder = "What's on your mind?"
    public static let voiceUnavailable = "Voice capture isn't available here. Your written words still stay on this phone."
    public static let captureFailed = "That didn't take. Your words were not lost — try once more."
    public static let saveFailed = "Couldn't keep that entry. Nothing left this phone; try again."

    // MARK: Weekly review

    public static let weeklyReviewLink = "This week"
    public static let weeklyReviewTitle = "This week"
    public static let weeklyReviewIntro = "What kept coming back, drawn only from your own words."
    public static let weeklyThemesHeader = "What kept coming back"
    public static let weeklyReviewEmpty = "A few more days of entries and there'll be something to look back on."
    public static let weeklyReviewUnavailable = "This week's reflection isn't ready on this phone. Your entries are all still here."
    public static let citationLabel = "From this entry"
    public static let supportHeader = "If it feels heavy right now"
    public static let supportIntro = "You don't have to sit with it alone. These are always here, any hour."

    // MARK: Quiet reassurance

    public static let stillness = "Works in airplane mode. Nothing leaves this phone."

    /// The compliance surface: every string above, for the banned-terms scan.
    public static let allStrings: [String] = [
        appName,
        timelineTitle,
        timelineEmpty,
        spokenLabel,
        writtenLabel,
        recordAccessibility,
        stopAccessibility,
        listening,
        readItBack,
        keepEntry,
        discardEntry,
        writeInstead,
        writePlaceholder,
        voiceUnavailable,
        captureFailed,
        saveFailed,
        weeklyReviewLink,
        weeklyReviewTitle,
        weeklyReviewIntro,
        weeklyThemesHeader,
        weeklyReviewEmpty,
        weeklyReviewUnavailable,
        citationLabel,
        supportHeader,
        supportIntro,
        stillness,
    ]
}
