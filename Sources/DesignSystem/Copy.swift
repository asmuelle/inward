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
        stillness,
    ]
}
