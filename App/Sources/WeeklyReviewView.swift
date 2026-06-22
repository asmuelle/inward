import DesignSystem
import Foundation
import JournalStore
import ReflectKit
import SafetyKit
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

    private let store: any JournalStoring
    private let provider: any WeeklyReviewProviding
    private let referenceDate: Date
    private let windowDays: Int
    private let calendar: Calendar

    init(
        store: any JournalStoring,
        provider: any WeeklyReviewProviding,
        referenceDate: Date = Date(),
        windowDays: Int = 7,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.provider = provider
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
        let weekEntries = entries.filter { $0.createdAt >= weekStart }
        entriesByID = Dictionary(weekEntries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let context = WeekContext(weekStart: weekStart, entries: weekEntries.map(Self.reviewable))
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

    /// Uses the summary precomputed and stored at save time (JournalStore.EntrySummary).
    static func reviewable(_ entry: Entry) -> ReviewableEntry {
        ReviewableEntry(id: entry.id, createdAt: entry.createdAt, summary: entry.summary)
    }
}

/// The weekly-review surface: gentle observations or recurring themes, each one
/// tappable back to the user's own words. The crisis state shows only static
/// resources — never model text.
struct WeeklyReviewView: View {
    @State private var model: WeeklyReviewModel

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
        .task { await model.load() }
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

        ForEach(themes, id: \.theme) { theme in
            PaperCard {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.element) {
                    Text("“\(theme.theme)”")
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                    Text(theme.count == 1 ? "in one entry" : "across \(theme.count) entries")
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
