import DesignSystem
import JournalStore
import SwiftUI

/// One kept entry on the timeline: serif first line on a paper card, with the
/// date and source as quiet sage metadata.
struct TimelineRow: View {
    let entry: Entry

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
                Text(firstLine)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardInk)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                HStack(spacing: Lamplight.Spacing.tight) {
                    Text(entry.createdAt, format: .dateTime.weekday(.wide).day().month())
                    Text("·")
                    Text(entry.source == .voice ? Copy.spokenLabel : Copy.writtenLabel)
                }
                .font(.lamplight(.caption))
                .foregroundStyle(Color.inwardSage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var firstLine: String {
        entry.textEdited
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? entry.textEdited
    }
}
