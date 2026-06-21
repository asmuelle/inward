import DesignSystem
import JournalStore
import SwiftUI

/// Reopen and read a kept entry — always available, never paywalled.
struct EntryDetailView: View {
    let entry: Entry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
                HStack(spacing: Lamplight.Spacing.tight) {
                    Text(entry.createdAt, format: .dateTime.weekday(.wide).day().month().year())
                    Text("·")
                    Text(entry.source == .voice ? Copy.spokenLabel : Copy.writtenLabel)
                }
                .font(.lamplight(.caption))
                .foregroundStyle(Color.inwardSage)

                Text(entry.textEdited)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardInk)
                    .lineSpacing(Lamplight.TypeRole.entryProse
                        .pointSize * (Lamplight.TypeRole.entryProse.lineSpacingMultiplier - 1))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Lamplight.Spacing.block)
        }
        .background(Color.inwardPaper.ignoresSafeArea())
        .inwardInlineTitle()
    }
}
