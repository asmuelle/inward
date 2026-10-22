import DesignSystem
import SwiftUI

/// Sharing, the Inward way: nothing leaves without being looked at first.
///
/// The sheet renders the card once and shows the user *that picture* — not a
/// live view that might differ from what gets sent. The share button hands the
/// same rendered image to the system sheet, so the preview is a promise, not an
/// approximation. No file is written, no link is minted, no request is made.
struct ShareCardSheet<Card: View>: View {
    private let card: Card

    @State private var rendered: Image?
    @Environment(\.dismiss) private var dismiss

    init(@ViewBuilder card: () -> Card) {
        self.card = card()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Lamplight.Spacing.block) {
                    preview
                    Text(Copy.shareSheetCaption)
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardSage)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    shareButton
                }
                .padding(Lamplight.Spacing.block)
            }
            .background(Color.inwardPaper.ignoresSafeArea())
            .navigationTitle(Copy.shareSheetTitle)
            .inwardInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.paywallClose) { dismiss() }
                        .foregroundStyle(Color.inwardClay)
                }
            }
        }
        // Rasterizing 1080x1350 takes a beat; do it once, off the first frame.
        .task { rendered = ShareCardRenderer.image(card) }
    }

    @ViewBuilder private var preview: some View {
        if let rendered {
            rendered
                .resizable()
                .aspectRatio(
                    Lamplight.ShareCard.size.width / Lamplight.ShareCard.size.height,
                    contentMode: .fit
                )
                .clipShape(RoundedRectangle(cornerRadius: Lamplight.Surface.cardRadius, style: .continuous))
                .shadow(
                    color: Color.inwardShadowTint.opacity(Lamplight.Surface.cardShadowOpacity),
                    radius: Lamplight.Surface.cardShadowRadius, y: 6
                )
                .accessibilityLabel(Copy.shareSheetTitle)
        } else {
            ProgressView()
                .tint(.inwardClay)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Lamplight.Spacing.stage)
        }
    }

    @ViewBuilder private var shareButton: some View {
        if let rendered {
            ShareLink(item: rendered, preview: SharePreview(Copy.appName, image: rendered)) {
                Text(Copy.shareSheetSend)
                    .font(.lamplight(.chrome))
                    .foregroundStyle(Color.inwardPaper)
                    .padding(.horizontal, Lamplight.Spacing.section)
                    .padding(.vertical, Lamplight.Spacing.element)
                    .background(Capsule().fill(Color.inwardClay))
            }
            .buttonStyle(.plain)
        }
    }
}

extension View {
    /// The standard share affordance: one toolbar button that opens the
    /// preview-first sheet. Kept in one place so every surface shares the same
    /// way — and so "what leaves the phone" has exactly one code path.
    func shareCardToolbar(
        isPresented: Binding<Bool>,
        @ViewBuilder card: @escaping () -> some View
    ) -> some View {
        toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isPresented.wrappedValue = true } label: {
                    Label(Copy.shareAction, systemImage: "square.and.arrow.up")
                }
                .tint(Color.inwardClay)
            }
        }
        .sheet(isPresented: isPresented) { ShareCardSheet(card: card) }
    }
}
