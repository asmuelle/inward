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

    // MARK: Onboarding (airplane-mode proof)

    public static let onboardingTitle = "Your words stay here"
    public static let onboardingPromise = "Everything you say or write is transcribed and kept on this phone. Nothing is uploaded — there's no account, and no server to breach."
    public static let onboardingProofTitle = "See it for yourself"
    public static let onboardingStep1 = "Turn on airplane mode."
    public static let onboardingStep2 = "Record or write your first entry — it still works."
    public static let onboardingStep3 = "Open Settings ▸ Privacy & Security ▸ App Privacy Report. Inward made no network activity."
    public static let onboardingBegin = "Begin"

    // MARK: Lock

    public static let lockTitle = "Locked"
    public static let lockSubtitle = "Your journal is yours alone."
    public static let lockUnlock = "Unlock"
    public static let unlockReason = "Unlock your journal"

    // MARK: Settings

    public static let settingsTitle = "Settings"
    public static let settingsDone = "Done"
    public static let settingsLockToggle = "Require Face ID or passcode"
    public static let settingsLockFooter = "Ask for Face ID, Touch ID, or your passcode each time Inward opens. Applies the next time you open the app."
    public static let settingsExport = "Export your journal"
    public static let settingsExportFooter = "Save an encrypted copy you can keep anywhere. Only your passphrase can open it, so store it somewhere safe — it can't be recovered."
    public static let settingsPrivacyFooter = "No accounts. No servers. No tracking."

    // MARK: Export

    public static let exportTitle = "Export your journal"
    public static let exportHint = "Your passphrase encrypts this export. There's no way to recover it, so write it down somewhere safe."
    public static let exportPassphrasePrompt = "Choose a passphrase"
    public static let exportPassphraseConfirm = "Repeat your passphrase"
    public static let exportAction = "Create encrypted export"
    public static let exportPassphraseRequired = "Enter a passphrase first."
    public static let exportWorking = "Encrypting…"
    public static let exportReady = "Your encrypted journal is ready."
    public static let exportShare = "Save or share"
    public static let exportFailed = "Couldn't create the export. Nothing left this phone; try again."

    // MARK: Membership / paywall

    public static let paywallTitle = "Keep Inward"
    public static let paywallSubtitle = "Unlimited writing and weekly reflections, kept on your phone. Reading and exporting your words are always free."
    public static let paywallTrialNote = "7 days free, then your plan. Cancel anytime."
    public static let paywallLifetimeNote = "Pay once. Yours to keep."
    public static let paywallBestValue = "Best value"
    public static let paywallRestore = "Restore a purchase"
    public static let paywallClose = "Not now"
    public static let paywallBusy = "Working…"
    public static let paywallReassurance = "No account. No servers. Your words never leave this phone."
    public static let membershipLink = "Membership"

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
        onboardingTitle,
        onboardingPromise,
        onboardingProofTitle,
        onboardingStep1,
        onboardingStep2,
        onboardingStep3,
        onboardingBegin,
        lockTitle,
        lockSubtitle,
        lockUnlock,
        unlockReason,
        settingsTitle,
        settingsDone,
        settingsLockToggle,
        settingsLockFooter,
        settingsExport,
        settingsExportFooter,
        settingsPrivacyFooter,
        exportTitle,
        exportHint,
        exportPassphrasePrompt,
        exportPassphraseConfirm,
        exportAction,
        exportPassphraseRequired,
        exportWorking,
        exportReady,
        exportShare,
        exportFailed,
        paywallTitle,
        paywallSubtitle,
        paywallTrialNote,
        paywallLifetimeNote,
        paywallBestValue,
        paywallRestore,
        paywallClose,
        paywallBusy,
        paywallReassurance,
        membershipLink,
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
