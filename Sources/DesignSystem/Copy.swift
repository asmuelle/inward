import Foundation

/// Every user-facing string in the M1 slice lives here, in the Lamplight voice:
/// quiet, second-person, never instructive. The compliance suite scans `allStrings`
/// against the banned-terms lexicon on every run — keep new copy in this file.
public enum Copy {
    public static let appName = Localized.t("appName", "Inward")

    // MARK: Timeline

    public static let timelineTitle = Localized.t("timelineTitle", "Inward")
    public static let timelineEmpty = Localized.t(
        "timelineEmpty",
        "Nothing here yet. When you're ready, speak — your words stay on this phone."
    )
    /// Shown in the detail pane of the iPad/macOS split layout before a pick.
    public static let detailPlaceholder = Localized.t("detailPlaceholder", "Choose an entry to read it here.")
    public static let spokenLabel = Localized.t("spokenLabel", "Spoken")
    public static let writtenLabel = Localized.t("writtenLabel", "Written")

    // MARK: Capture

    public static let recordAccessibility = Localized.t("recordAccessibility", "Start recording")
    public static let stopAccessibility = Localized.t("stopAccessibility", "Stop recording")
    public static let listening = Localized.t("listening", "Listening…")
    public static let readItBack = Localized.t("readItBack", "Read it back")
    public static let keepEntry = Localized.t("keepEntry", "Keep this entry")
    public static let discardEntry = Localized.t("discardEntry", "Discard")
    public static let writeInstead = Localized.t("writeInstead", "Write instead")
    public static let writePlaceholder = Localized.t("writePlaceholder", "What's on your mind?")
    public static let voiceUnavailable = Localized.t(
        "voiceUnavailable",
        "Voice capture isn't available here. Your written words still stay on this phone."
    )
    public static let captureFailed = Localized.t("captureFailed", "That didn't take. Your words were not lost — try once more.")
    public static let saveFailed = Localized.t("saveFailed", "Couldn't keep that entry. Nothing left this phone; try again.")

    // MARK: Voice preparation (one-time, consented model download)

    public static let voicePrepareTitle = Localized.t("voicePrepareTitle", "Set voice up once")
    public static let voicePrepareBody = Localized.t(
        "voicePrepareBody",
        "Voice needs to bring its language onto this phone first. That's the one time Inward uses a connection — " +
            "afterwards, recording works in airplane mode and nothing leaves this phone. Writing already works offline."
    )
    public static let voicePrepareAction = Localized.t("voicePrepareAction", "Bring voice onto this phone")
    public static let voicePreparing = Localized.t("voicePreparing", "Bringing voice onto this phone…")

    // MARK: Spoken summary confirm loop

    /// Shown while the recap is being formed and read aloud.
    public static let summarizingLabel = Localized.t("summarizingLabel", "Reading it back…")
    /// "Keep" on the spoken confirm screen — terser than `keepEntry`.
    public static let confirmKeep = Localized.t("confirmKeep", "Keep")
    /// "Add more" — invites another spoken round before keeping.
    public static let confirmAddMore = Localized.t("confirmAddMore", "Add more")
    /// The fixed open question used when no on-device model is available to
    /// generate one. Passed to `DeterministicCaptureSummaryProvider`.
    public static let clarifyDefaultQuestion = Localized.t(
        "clarifyDefaultQuestion",
        "What else feels worth saying about this?"
    )
    public static let settingsSpokenSummaryToggle = Localized.t("settingsSpokenSummaryToggle", "Read my notes back")
    public static let settingsSpokenSummaryFooter = Localized.t(
        "settingsSpokenSummaryFooter",
        "After a recording, Inward speaks a short summary and asks whether to keep it. Everything stays on this phone."
    )

    // MARK: Weekly review

    public static let weeklyReviewLink = Localized.t("weeklyReviewLink", "This week")
    public static let weeklyReviewTitle = Localized.t("weeklyReviewTitle", "This week")
    public static let weeklyReviewIntro = Localized.t(
        "weeklyReviewIntro",
        "What kept coming back, drawn only from your own words."
    )
    public static let weeklyThemesHeader = Localized.t("weeklyThemesHeader", "What kept coming back")
    public static let weeklyReviewEmpty = Localized.t(
        "weeklyReviewEmpty",
        "A few more days of entries and there'll be something to look back on."
    )
    public static let weeklyReviewUnavailable = Localized.t(
        "weeklyReviewUnavailable",
        "This week's reflection isn't ready on this phone. Your entries are all still here."
    )
    public static let citationLabel = Localized.t("citationLabel", "From this entry")
    public static let supportHeader = Localized.t("supportHeader", "If it feels heavy right now")
    public static let supportIntro = Localized.t(
        "supportIntro",
        "You don't have to sit with it alone. These are always here, any hour."
    )

    // MARK: Onboarding (airplane-mode proof)

    public static let onboardingTitle = Localized.t("onboardingTitle", "Your words stay here")
    public static let onboardingPromise = Localized.t(
        "onboardingPromise",
        "Everything you say or write is transcribed and kept on this phone. Nothing is uploaded — there's no account, and no server to breach."
    )
    public static let onboardingProofTitle = Localized.t("onboardingProofTitle", "See it for yourself")
    public static let onboardingStep1 = Localized.t("onboardingStep1", "Turn on airplane mode.")
    public static let onboardingStep2 = Localized.t("onboardingStep2", "Record or write your first entry — it still works.")
    public static let onboardingStep3 = Localized.t(
        "onboardingStep3",
        "Open Settings ▸ Privacy & Security ▸ App Privacy Report. Inward made no network activity."
    )
    public static let onboardingBegin = Localized.t("onboardingBegin", "Begin")

    // MARK: Lock

    public static let lockTitle = Localized.t("lockTitle", "Locked")
    public static let lockSubtitle = Localized.t("lockSubtitle", "Your journal is yours alone.")
    public static let lockUnlock = Localized.t("lockUnlock", "Unlock")
    public static let unlockReason = Localized.t("unlockReason", "Unlock your journal")

    // MARK: Settings

    public static let settingsTitle = Localized.t("settingsTitle", "Settings")
    public static let settingsDone = Localized.t("settingsDone", "Done")
    public static let settingsLockToggle = Localized.t("settingsLockToggle", "Require Face ID or passcode")
    public static let settingsLockFooter = Localized.t(
        "settingsLockFooter",
        "Ask for Face ID, Touch ID, or your passcode each time Inward opens. Applies the next time you open the app."
    )
    public static let settingsExport = Localized.t("settingsExport", "Export your journal")
    public static let settingsExportFooter = Localized.t(
        "settingsExportFooter",
        "Save an encrypted copy you can keep anywhere. Only your passphrase can open it, so store it somewhere safe — it can't be recovered."
    )
    public static let settingsImport = Localized.t("settingsImport", "Bring in a journal")
    public static let settingsImportFooter = Localized.t(
        "settingsImportFooter",
        "Open an encrypted export from another device. Entries you already have stay untouched; only new ones are added."
    )
    public static let settingsPrivacyFooter = Localized.t("settingsPrivacyFooter", "No accounts. No servers. No tracking.")

    // MARK: Export

    public static let exportTitle = Localized.t("exportTitle", "Export your journal")
    public static let exportHint = Localized.t(
        "exportHint",
        "Your passphrase encrypts this export. There's no way to recover it, so write it down somewhere safe."
    )
    public static let exportPassphrasePrompt = Localized.t("exportPassphrasePrompt", "Choose a passphrase")
    public static let exportPassphraseConfirm = Localized.t("exportPassphraseConfirm", "Repeat your passphrase")
    public static let exportAction = Localized.t("exportAction", "Create encrypted export")
    public static let exportPassphraseRequired = Localized.t("exportPassphraseRequired", "Enter a passphrase first.")
    public static let exportWorking = Localized.t("exportWorking", "Encrypting…")
    public static let exportReady = Localized.t("exportReady", "Your encrypted journal is ready.")
    public static let exportShare = Localized.t("exportShare", "Save or share")
    public static let exportFailed = Localized.t(
        "exportFailed",
        "Couldn't create the export. Nothing left this phone; try again."
    )

    // MARK: Import

    public static let importTitle = Localized.t("importTitle", "Bring in a journal")
    public static let importHint = Localized.t(
        "importHint",
        "Choose an encrypted export from another device, then enter the passphrase you sealed it with. Entries you already have stay as they are."
    )
    public static let importPassphrasePrompt = Localized.t("importPassphrasePrompt", "Enter the passphrase")
    public static let importChooseFile = Localized.t("importChooseFile", "Choose a backup file")
    public static let importAction = Localized.t("importAction", "Open and merge")
    public static let importWorking = Localized.t("importWorking", "Opening…")
    public static let importPassphraseRequired = Localized.t("importPassphraseRequired", "Enter the passphrase first.")
    public static let importWrongPassphrase = Localized.t(
        "importWrongPassphrase",
        "That passphrase didn't open the file, or the file was changed. Nothing was imported."
    )
    public static let importFailed = Localized.t("importFailed", "Couldn't open that file. Nothing on this device changed.")

    /// Result line: "Added 12 entries." / "Added 1 entry." / "Already up to date."
    public static func importDone(added: Int) -> String {
        switch added {
        case 0: Localized.t("importDoneNone", "Already up to date — nothing new to add.")
        case 1: Localized.t("importDoneOne", "Added 1 entry.")
        default: String(format: Localized.t("importDoneMany", "Added %d entries."), added)
        }
    }

    // MARK: Entry maintenance

    public static let entryEdit = Localized.t("entryEdit", "Edit")
    public static let entryDelete = Localized.t("entryDelete", "Delete")
    public static let entryEditSave = Localized.t("entryEditSave", "Save")
    public static let entryEditCancel = Localized.t("entryEditCancel", "Cancel")
    /// Quiet marker shown after the date when an entry has been edited.
    public static let entryEditedMarker = Localized.t("entryEditedMarker", "edited")
    public static let entryDeleteConfirmTitle = Localized.t("entryDeleteConfirmTitle", "Delete this entry?")
    public static let entryDeleteConfirmAction = Localized.t("entryDeleteConfirmAction", "Delete")
    public static let entryDeleted = Localized.t("entryDeleted", "Entry deleted")
    public static let entryDeleteUndo = Localized.t("entryDeleteUndo", "Undo")
    public static let tagsLabel = Localized.t("tagsLabel", "Tags")
    public static let tagAddPlaceholder = Localized.t("tagAddPlaceholder", "Add a tag")
    public static let tagsSuggestedLabel = Localized.t("tagsSuggestedLabel", "Suggested")

    // MARK: Mind map

    public static let mindMapLink = Localized.t("mindMapLink", "Mind map")
    public static let mindMapTitle = Localized.t("mindMapTitle", "Mind map")
    public static let mindMapEmpty = Localized.t("mindMapEmpty", "Names, places, and themes gather here as you write.")
    public static let mindMapPeople = Localized.t("mindMapPeople", "People")
    public static let mindMapPlaces = Localized.t("mindMapPlaces", "Places")
    public static let mindMapThings = Localized.t("mindMapThings", "Things")
    public static let mindMapTopics = Localized.t("mindMapTopics", "Topics")
    public static let mindMapSearchPrompt = Localized.t("mindMapSearchPrompt", "Search names and topics")
    public static let mindMapModeMap = Localized.t("mindMapModeMap", "Map")
    public static let mindMapModeList = Localized.t("mindMapModeList", "List")
    public static let mindMapNodeHint = Localized.t("mindMapNodeHint", "Opens the entries it came from")

    /// VoiceOver / list count: "1 mention" / "5 mentions".
    public static func mindMapMentions(_ count: Int) -> String {
        count == 1
            ? Localized.t("mindMapMentionsOne", "1 mention")
            : String(format: Localized.t("mindMapMentionsMany", "%d mentions"), count)
    }

    // MARK: Membership / paywall

    public static let paywallTitle = Localized.t("paywallTitle", "Keep Inward")
    public static let paywallSubtitle = Localized.t(
        "paywallSubtitle",
        "Unlimited writing and weekly reflections, kept on your phone. Reading and exporting your words are always free."
    )
    public static let paywallTrialNote = Localized.t("paywallTrialNote", "7 days free, then your plan. Cancel anytime.")
    public static let paywallLifetimeNote = Localized.t("paywallLifetimeNote", "Pay once. Yours to keep.")
    public static let paywallBestValue = Localized.t("paywallBestValue", "Best value")
    public static let paywallRestore = Localized.t("paywallRestore", "Restore a purchase")
    public static let paywallClose = Localized.t("paywallClose", "Not now")
    public static let paywallBusy = Localized.t("paywallBusy", "Working…")
    public static let paywallReassurance = Localized.t(
        "paywallReassurance",
        "No account. No servers. Your words never leave this phone."
    )
    public static let membershipLink = Localized.t("membershipLink", "Membership")

    // MARK: Quiet reassurance

    public static let stillness = Localized.t("stillness", "Works in airplane mode. Nothing leaves this phone.")

    /// The compliance surface: every string above, for the banned-terms scan.
    public static let allStrings: [String] = [
        appName,
        timelineTitle,
        timelineEmpty,
        detailPlaceholder,
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
        voicePrepareTitle,
        voicePrepareBody,
        voicePrepareAction,
        voicePreparing,
        summarizingLabel,
        confirmKeep,
        confirmAddMore,
        clarifyDefaultQuestion,
        settingsSpokenSummaryToggle,
        settingsSpokenSummaryFooter,
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
        settingsImport,
        settingsImportFooter,
        importTitle,
        importHint,
        importPassphrasePrompt,
        importChooseFile,
        importAction,
        importWorking,
        importPassphraseRequired,
        importWrongPassphrase,
        importFailed,
        entryEdit,
        entryDelete,
        entryEditSave,
        entryEditCancel,
        entryEditedMarker,
        entryDeleteConfirmTitle,
        entryDeleteConfirmAction,
        entryDeleted,
        entryDeleteUndo,
        tagsLabel,
        tagAddPlaceholder,
        tagsSuggestedLabel,
        mindMapLink,
        mindMapTitle,
        mindMapEmpty,
        mindMapPeople,
        mindMapPlaces,
        mindMapThings,
        mindMapTopics,
        mindMapSearchPrompt,
        mindMapModeMap,
        mindMapModeList,
        mindMapNodeHint,
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
