import DesignSystem
import PaywallKit
import SwiftUI

/// The hard paywall: annual-first options, restore, and the standing promise that
/// reading and exporting are always free. Dismisses itself once a purchase unlocks
/// the app.
struct PaywallView: View {
    @State private var model: PaywallModel
    @Environment(\.dismiss) private var dismiss

    init(model: PaywallModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.section) {
                    header
                    options
                    footer
                }
                .padding(Lamplight.Spacing.block)
            }
            .background(Color.inwardPaper.ignoresSafeArea())
            .navigationTitle(Copy.paywallTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Copy.paywallClose) { dismiss() }
                        .font(.lamplight(.chrome))
                }
            }
            .task { await model.refresh() }
            .onChange(of: model.isLocked) { _, locked in
                if !locked { dismiss() }
            }
        }
    }

    private var header: some View {
        Text(Copy.paywallSubtitle)
            .font(.lamplight(.entryProse))
            .foregroundStyle(Color.inwardInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var options: some View {
        if model.products.isEmpty {
            ProgressView().tint(.inwardClay)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: Lamplight.Spacing.element) {
                ForEach(model.products) { product in
                    optionButton(product)
                }
            }
            .disabled(model.isWorking)
        }
    }

    private func optionButton(_ product: PaywallProduct) -> some View {
        let highlighted = product.kind == .annual
        return Button {
            Task {
                _ = await model.purchase(product.id)
            }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.hairline) {
                    Text(product.displayName)
                        .font(.lamplight(.entryProse))
                    Text(product.kind == .lifetime ? Copy.paywallLifetimeNote : Copy.paywallTrialNote)
                        .font(.lamplight(.caption))
                        .foregroundStyle(highlighted ? Color.inwardPaper.opacity(0.85) : Color.inwardSage)
                }
                Spacer()
                if highlighted {
                    Text(Copy.paywallBestValue)
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardPaper)
                        .padding(.horizontal, Lamplight.Spacing.tight)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.inwardInk.opacity(0.25)))
                }
                Text(product.displayPrice)
                    .font(.lamplight(.chrome))
            }
            .foregroundStyle(highlighted ? Color.inwardPaper : Color.inwardInk)
            .padding(Lamplight.Spacing.block)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Lamplight.Surface.cardRadius, style: .continuous)
                    .fill(highlighted ? Color.inwardClay : Color.inwardPaper)
                    .stroke(Color.inwardSage.opacity(highlighted ? 0 : 0.4), lineWidth: 1)
                    .shadow(
                        color: Color.inwardShadowTint.opacity(Lamplight.Surface.cardShadowOpacity),
                        radius: Lamplight.Surface.cardShadowRadius / 2, y: 4
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: Lamplight.Spacing.element) {
            if model.isWorking {
                HStack(spacing: Lamplight.Spacing.tight) {
                    ProgressView().tint(.inwardClay)
                    Text(Copy.paywallBusy)
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardSage)
                }
            }
            Button(Copy.paywallRestore) {
                Task { await model.restore() }
            }
            .font(.lamplight(.chrome))
            .foregroundStyle(Color.inwardClay)
            .disabled(model.isWorking)

            Text(Copy.paywallReassurance)
                .font(.lamplight(.caption))
                .foregroundStyle(Color.inwardSage)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
