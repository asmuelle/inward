import DesignSystem
import SwiftUI

/// The standing "Proof" screen (DESIGN.md flow #4, on demand): live airplane-mode
/// state, an invitation to record while offline, where the words live, and honest
/// guided steps to iOS's App Privacy Report — there is no public deep link to
/// that pane, so guidance is the truthful ceiling. Every line here must stay
/// literally accurate; the claim is the product.
struct ProofView: View {
    /// Dismisses the surrounding surface and opens capture, so the proof can be
    /// felt, not just read.
    let onTryCapture: () -> Void

    @State private var connectivity = ConnectivityMonitor()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.section) {
                liveStatusCard
                dataCard
                reportCard
            }
            .padding(Lamplight.Spacing.block)
        }
        .background(Color.inwardPaper.ignoresSafeArea())
        .navigationTitle(Copy.proofTitle)
        .inwardInlineTitle()
        .task { connectivity.start() }
        .onDisappear { connectivity.stop() }
    }

    private var liveStatusCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.element) {
                HStack(spacing: Lamplight.Spacing.tight) {
                    Image(systemName: connectivity.isOffline ? "airplane" : "wifi")
                        .foregroundStyle(connectivity.isOffline ? Color.inwardClay : Color.inwardSage)
                    Text(connectivity.isOffline ? Copy.proofOfflineConfirm : Copy.proofOnlineHint)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if connectivity.isOffline {
                    Button(action: onTryCapture) {
                        Text(Copy.proofTryCapture)
                            .font(.lamplight(.chrome))
                            .foregroundStyle(Color.inwardPaper)
                            .padding(.horizontal, Lamplight.Spacing.block)
                            .padding(.vertical, Lamplight.Spacing.element)
                            .background(Capsule().fill(Color.inwardClay))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.easeOut(duration: Lamplight.Motion.standard), value: connectivity.isOffline)
    }

    private var dataCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
                Text(Copy.proofDataTitle)
                    .font(.lamplight(.chrome))
                    .foregroundStyle(Color.inwardInk)
                Text(Copy.proofDataBody)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reportCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
                Text(Copy.proofReportTitle)
                    .font(.lamplight(.chrome))
                    .foregroundStyle(Color.inwardInk)
                Text(Copy.proofReportBody)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardInk)
                    .fixedSize(horizontal: false, vertical: true)
                #if os(iOS)
                    // Lands on this app's settings page — the closest a third-party
                    // app can honestly get to the App Privacy Report pane.
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link(Copy.proofOpenSettings, destination: url)
                            .font(.lamplight(.caption))
                            .foregroundStyle(Color.inwardClay)
                    }
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
