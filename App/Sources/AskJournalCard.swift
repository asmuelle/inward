import DesignSystem
import JournalStore
import ReflectKit
import SafetyKit
import SwiftUI

/// The ask card that sits above search results when the query reads as a
/// question: one tap asks the entries, and the answer arrives as short prose
/// pinned to the entries it came from. The crisis state shows only static
/// resources — never model text. The retrieved entries stay listed underneath
/// in every state, so a quiet "not found" is never a dead end.
struct AskJournalCard: View {
    let model: AskJournalModel
    let onAsk: () -> Void
    let onOpen: (Entry) -> Void
    let onClear: () -> Void

    var body: some View {
        switch model.state {
        case .idle:
            askButton
        case .asking:
            PaperCard {
                HStack(spacing: Lamplight.Spacing.tight) {
                    ProgressView().tint(.inwardClay)
                    Text(Copy.askEntriesReading)
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardSage)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case let .answered(outcome):
            answered(outcome)
        }
    }

    private var askButton: some View {
        Button(action: onAsk) {
            HStack(spacing: Lamplight.Spacing.tight) {
                Image(systemName: "text.magnifyingglass")
                Text(Copy.askEntriesButton)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .font(.lamplight(.chrome))
            .foregroundStyle(Color.inwardClay)
            .padding(.horizontal, Lamplight.Spacing.element)
            .padding(.vertical, Lamplight.Spacing.tight)
            .background(
                RoundedRectangle(cornerRadius: Lamplight.Surface.cardRadius, style: .continuous)
                    .stroke(Color.inwardClay.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func answered(_ outcome: JournalQuestionOutcome) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.element) {
                header
                switch outcome {
                case let .answered(answer):
                    Text(answer.answer)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                        .fixedSize(horizontal: false, vertical: true)
                    citations(answer.citedEntryIds)
                case .notInEntries:
                    quiet(Copy.askEntriesNotFound)
                case .unavailable:
                    quiet(Copy.askEntriesUnavailable)
                case let .suppressed(resources):
                    support(resources)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack {
            Text(Copy.askEntriesHeader.uppercased())
                .font(.lamplight(.caption))
                .tracking(1.1)
                .foregroundStyle(Color.inwardSage)
            Spacer()
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.inwardSage)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.askEntriesClear)
        }
    }

    private func quiet(_ message: String) -> some View {
        Text(message)
            .font(.lamplight(.entryProse))
            .foregroundStyle(Color.inwardSage)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func support(_ resources: [SupportResource]) -> some View {
        Text(Copy.supportHeader)
            .font(.lamplight(.journalTitle))
            .foregroundStyle(Color.inwardInk)
        Text(Copy.supportIntro)
            .font(.lamplight(.entryProse))
            .foregroundStyle(Color.inwardInk)
            .fixedSize(horizontal: false, vertical: true)
        ForEach(resources) { resource in
            VStack(alignment: .leading, spacing: Lamplight.Spacing.hairline) {
                Text(resource.name)
                    .font(.lamplight(.chrome))
                    .foregroundStyle(Color.inwardInk)
                Text(resource.detail)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Mirrors the weekly review's citation rows so both surfaces read as one.
    private func citations(_ ids: [UUID]) -> some View {
        VStack(alignment: .leading, spacing: Lamplight.Spacing.hairline) {
            ForEach(ids, id: \.self) { id in
                if let entry = model.entry(for: id) {
                    Button {
                        onOpen(entry)
                    } label: {
                        HStack(spacing: Lamplight.Spacing.tight) {
                            Image(systemName: "arrow.up.right")
                            Text(entry.createdAt, format: .dateTime.weekday(.abbreviated).day().month())
                            Text(entry.summary)
                                .lineLimit(1)
                        }
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardClay)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Copy.citationLabel)
                }
            }
        }
    }
}
