import DesignSystem
import JournalStore
import SwiftUI

/// One kept entry on the timeline: serif first line on a paper card, with the
/// date and source as quiet sage metadata.
struct TimelineRow: View {
    let entry: Entry
    /// Drawn selected in the iPad/macOS split layout, where the timeline stays
    /// visible beside the open entry. Always false in the iPhone push layout.
    var isSelected: Bool = false

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
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Lamplight.Surface.cardRadius, style: .continuous)
                    .stroke(Color.inwardClay, lineWidth: 2)
            }
        }
    }

    private var firstLine: String {
        entry.textEdited
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? entry.textEdited
    }
}
