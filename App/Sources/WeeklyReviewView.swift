import DesignSystem
import Foundation
import JournalStore
import ReflectKit
import SafetyKit
import StoreKit
import SwiftUI

/// Assembles the week from the store, runs it through the verified-citation
/// pipeline, and exposes the outcome plus an id→entry lookup so citations can
/// open the original entries. Read-only; never writes.
@MainActor
@Observable
final class WeeklyReviewModel {
    /// `nil` while loading; a resolved `WeeklyReviewOutcome` after.
    private(set) var outcome: WeeklyReviewOutcome?
    private(set) var entriesByID: [UUID: Entry] = [:]
    /// Deterministic "when you wrote" fact for the week; nil under two entries.
    private(set) var rhythm: TimeRhythm?
    /// Start of the reviewed window, kept for the share card's date line.
    private(set) var weekStart: Date?

    private let store: any JournalStoring
    private let provider: any WeeklyReviewProviding
    private let referenceDate: Date
    private let windowDays: Int
    private let calendar: Calendar

    init(
        store: any JournalStoring,
        provider: any WeeklyReviewProviding,
        synthesisAllowed: Bool = true,
        referenceDate: Date = Date(),
        windowDays: Int = 7,
        calendar: Calendar = .current
    ) {
        self.store = store
        // Synthesis is Pro; without it the provider
        // reports unavailable and the review degrades to deterministic
        // themes-only counts — the crisis gate still runs first, unchanged.
        self.provider = synthesisAllowed ? provider : SynthesisWithheldProvider()
        self.referenceDate = referenceDate
        self.windowDays = windowDays
        self.calendar = calendar
    }

    var hasEntriesThisWeek: Bool {
        !entriesByID.isEmpty
    }

    func load() async {
        let entries: [Entry]
        do {
            entries = try await store.allEntries()
        } catch {
            outcome = .unavailable
            return
        }

        let weekStart = calendar.date(byAdding: .day, value: -windowDays, to: referenceDate) ?? referenceDate
        self.weekStart = weekStart
        let weekEntries = entries.filter { $0.createdAt >= weekStart }
        entriesByID = Dictionary(weekEntries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let context = WeekContext(weekStart: weekStart, entries: weekEntries.map(Self.reviewable))
        rhythm = WeeklyReviewPipeline.timeRhythm(in: context, calendar: calendar)
        let result = await WeeklyReviewPipeline(
            gate: CrisisGate(localizedFor: .current),
            provider: provider
        ).review(for: context)

        // Model-optional (invariant #9): if the on-device model is unavailable but
        // there are entries, still surface the deterministic recurring themes.
        if case .unavailable = result, !context.entries.isEmpty {
            let themes = WeeklyReviewPipeline.recurringThemes(in: context)
            outcome = themes.isEmpty ? .unavailable : .themesOnly(themes)
        } else {
            outcome = result
        }
    }

    func entry(for id: UUID) -> Entry? {
        entriesByID[id]
    }

    /// Theme words for the share card — words only, never an observation and
    /// never a line the user wrote. `nil` wherever there is no picture worth
    /// making: the crisis state (static resources only), and the empty states.
    var shareableThemes: [String]? {
        let themes: [String]
        switch outcome {
        case let .synthesized(draft): themes = draft.observations.map(\.theme)
        case let .themesOnly(counts): themes = counts.map(\.theme)
        case .suppressed, .unavailable, .none: return nil
        }
        return themes.isEmpty ? nil : themes
    }

    /// "18–25 Jul" for the card's date line, in the reader's locale.
    var weekRangeText: String {
        guard let weekStart else { return "" }
        return (weekStart ..< referenceDate).formatted(.interval.day().month(.abbreviated))
    }

    /// Uses the summary precomputed and stored at save time (JournalStore.EntrySummary).
    static func reviewable(_ entry: Entry) -> ReviewableEntry {
        ReviewableEntry(id: entry.id, createdAt: entry.createdAt, summary: entry.summary, timeZone: entry.timeZone)
    }
}

/// Stands in for the synthesis provider when the entitlement doesn't cover it:
/// always unavailable, so the pipeline (crisis gate included) degrades to the
/// deterministic themes-only outcome without a second code path.
private struct SynthesisWithheldProvider: WeeklyReviewProviding {
    func availability() async -> ReflectionAvailability {
        .unavailable(reason: "synthesis is part of Inward Pro")
    }

    func review(for _: WeekContext) async throws -> WeeklyReviewDraft {
        throw ReflectionError.modelUnavailable
    }
}

/// The weekly-review surface: gentle observations or recurring themes, each one
/// tappable back to the user's own words. The crisis state shows only static
/// resources — never model text.
struct WeeklyReviewView: View {
    @State private var model: WeeklyReviewModel
    @State private var isSharing = false
    @Environment(\.requestReview) private var requestReview

    init(model: WeeklyReviewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.section) {
                content
            }
            .padding(Lamplight.Spacing.block)
            .padding(.bottom, Lamplight.Spacing.stage)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.inwardPaper.ignoresSafeArea())
        .navigationTitle(Copy.weeklyReviewTitle)
        .inwardInlineTitle()
        .task {
            await model.load()
            await askForReviewIfEarned()
        }
        .modifier(ShareThemesToolbar(themes: model.shareableThemes, range: model.weekRangeText, isSharing: $isSharing))
    }

    /// The one rating ask, at the one moment the app has demonstrably been
    /// worth something: a week gathered into themes the user can tap back into.
    /// Never in the crisis state, never twice, and never on a hollow week —
    /// `ReviewPrompt` owns those rules so they can be tested without StoreKit.
    private func askForReviewIfEarned() async {
        let defaults = UserDefaults.standard
        guard ReviewPrompt.shouldAsk(
            for: model.outcome,
            alreadyAsked: defaults.bool(forKey: Prefs.hasAskedForReview)
        ) else { return }
        defaults.set(true, forKey: Prefs.hasAskedForReview)
        // Let the review land and be read before the system sheet arrives.
        try? await Task.sleep(for: .seconds(ReviewPrompt.settleDelay))
        requestReview()
    }

    @ViewBuilder private var content: some View {
        switch model.outcome {
        case .none:
            ProgressView()
                .tint(.inwardClay)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Lamplight.Spacing.stage)
        case let .synthesized(draft):
            synthesized(draft)
        case let .themesOnly(themes):
            themesOnly(themes)
        case let .suppressed(resources):
            support(resources)
        case .unavailable:
            quiet(model.hasEntriesThisWeek ? Copy.weeklyReviewUnavailable : Copy.weeklyReviewEmpty)
        }
    }

    // MARK: - States

    @ViewBuilder private func synthesized(_ draft: WeeklyReviewDraft) -> some View {
        Text(Copy.weeklyReviewIntro)
            .font(.lamplight(.caption))
            .foregroundStyle(Color.inwardSage)

        rhythmLine

        ForEach(Array(draft.observations.enumerated()), id: \.offset) { _, observation in
            PaperCard {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.element) {
                    themeLabel(observation.theme)
                    Text(observation.note)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                        .fixedSize(horizontal: false, vertical: true)
                    citations(observation.citedEntryIds)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private func themesOnly(_ themes: [ThemeCount]) -> some View {
        Text(Copy.weeklyThemesHeader)
            .font(.lamplight(.journalTitle))
            .foregroundStyle(Color.inwardInk)

        rhythmLine

        ForEach(themes, id: \.theme) { theme in
            PaperCard {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.element) {
                    Text("“\(theme.theme)”")
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                    Text(Copy.weeklyThemeEntryCount(theme.count))
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardSage)
                    citations(theme.entryIds)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private func support(_ resources: [SupportResource]) -> some View {
        VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
            Text(Copy.supportHeader)
                .font(.lamplight(.journalTitle))
                .foregroundStyle(Color.inwardInk)
            Text(Copy.supportIntro)
                .font(.lamplight(.entryProse))
                .foregroundStyle(Color.inwardInk)
                .fixedSize(horizontal: false, vertical: true)
        }

        ForEach(resources) { resource in
            PaperCard {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
                    Text(resource.name)
                        .font(.lamplight(.chrome))
                        .foregroundStyle(Color.inwardInk)
                    Text(resource.detail)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func quiet(_ message: String) -> some View {
        Text(message)
            .font(.lamplight(.entryProse))
            .foregroundStyle(Color.inwardSage)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, Lamplight.Spacing.stage)
    }

    // MARK: - Pieces

    /// Deterministic rhythm fact, verifiable against the timeline — never shown
    /// in the crisis state, which renders only static resources.
    @ViewBuilder private var rhythmLine: some View {
        if let rhythm = model.rhythm {
            HStack(spacing: Lamplight.Spacing.tight) {
                Image(systemName: DayPartGlyph.symbolName(for: rhythm.dayPart))
                Text(Self.rhythmText(rhythm))
            }
            .font(.lamplight(.caption))
            .foregroundStyle(Color.inwardSage)
        }
    }

    static func rhythmText(_ rhythm: TimeRhythm) -> String {
        switch rhythm.dayPart {
        case .morning: Copy.weeklyRhythmMorning(rhythm.count, of: rhythm.total)
        case .afternoon: Copy.weeklyRhythmAfternoon(rhythm.count, of: rhythm.total)
        case .evening: Copy.weeklyRhythmEvening(rhythm.count, of: rhythm.total)
        case .lateNight: Copy.weeklyRhythmLateNight(rhythm.count, of: rhythm.total)
        }
    }

    private func themeLabel(_ theme: String) -> some View {
        Text(theme.uppercased())
            .font(.lamplight(.caption))
            .tracking(1.1)
            .foregroundStyle(Color.inwardSage)
    }

    private func citations(_ ids: [UUID]) -> some View {
        VStack(alignment: .leading, spacing: Lamplight.Spacing.hairline) {
            ForEach(ids, id: \.self) { id in
                if let entry = model.entry(for: id) {
                    NavigationLink(value: entry) {
                        HStack(spacing: Lamplight.Spacing.tight) {
                            Image(systemName: "arrow.up.right")
                            Text(entry.createdAt, format: .dateTime.weekday(.abbreviated).day().month())
                        }
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardClay)
                    }
                    .accessibilityLabel(Copy.citationLabel)
                }
            }
        }
        .padding(.top, Lamplight.Spacing.hairline)
    }
}

/// Adds the share affordance only when there are theme words worth picturing.
/// There is deliberately no share button in the crisis-suppressed state (static
/// resources only, never a poster) or in the empty and unavailable states.
private struct ShareThemesToolbar: ViewModifier {
    let themes: [String]?
    let range: String
    @Binding var isSharing: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if let themes {
            content.shareCardToolbar(isPresented: $isSharing) {
                ThemesShareCard(themes: themes, dateRange: range)
            }
        } else {
            content
        }
    }
}
