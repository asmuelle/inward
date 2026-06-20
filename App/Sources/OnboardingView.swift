import DesignSystem
import SwiftUI

/// First run: the privacy promise and the airplane-mode proof — the flow that
/// doubles as the launch demo. It asks the user to verify, themselves, that
/// nothing leaves the phone (DESIGN.md flow #4).
struct OnboardingView: View {
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.section) {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.element) {
                    Text(Copy.onboardingTitle)
                        .font(.lamplight(.journalTitle))
                        .foregroundStyle(Color.inwardInk)
                    Text(Copy.onboardingPromise)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PaperCard {
                    VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
                        Text(Copy.onboardingProofTitle)
                            .font(.lamplight(.chrome))
                            .foregroundStyle(Color.inwardSage)
                        proofStep(number: 1, Copy.onboardingStep1)
                        proofStep(number: 2, Copy.onboardingStep2)
                        proofStep(number: 3, Copy.onboardingStep3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: onDone) {
                    Text(Copy.onboardingBegin)
                        .font(.lamplight(.chrome))
                        .foregroundStyle(Color.inwardPaper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Lamplight.Spacing.element)
                        .background(Capsule().fill(Color.inwardClay))
                }
                .buttonStyle(.plain)
            }
            .padding(Lamplight.Spacing.block)
            .padding(.top, Lamplight.Spacing.stage)
        }
        .background(Color.inwardPaper.ignoresSafeArea())
    }

    private func proofStep(number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Lamplight.Spacing.element) {
            Text("\(number)")
                .font(.lamplight(.chrome))
                .foregroundStyle(Color.inwardClay)
            Text(text)
                .font(.lamplight(.entryProse))
                .foregroundStyle(Color.inwardInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
