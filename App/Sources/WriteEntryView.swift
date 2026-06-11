import CaptureKit
import DesignSystem
import SwiftUI

/// The text fallback: the same loop as voice, minus the engine. Always available,
/// so journaling fully works when ASR is not (invariant #9).
struct WriteEntryView: View {
    @Bindable private var coordinator: CaptureCoordinator
    private let onFinished: () -> Void

    @State private var text = ""

    init(coordinator: CaptureCoordinator, onFinished: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
            Text(Copy.writeInstead)
                .font(.lamplight(.journalTitle))
                .foregroundStyle(Color.inwardInk)

            PaperCard {
                TextEditor(text: $text)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 220)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(Copy.writePlaceholder)
                                .font(.lamplight(.entryProse))
                                .foregroundStyle(Color.inwardSage)
                                .allowsHitTesting(false)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
            }

            HStack {
                Button(Copy.discardEntry) {
                    onFinished()
                }
                .font(.lamplight(.chrome))
                .foregroundStyle(Color.inwardSage)

                Spacer()

                Button {
                    Task {
                        await coordinator.saveWrittenEntry(text)
                        onFinished()
                    }
                } label: {
                    Text(Copy.keepEntry)
                        .font(.lamplight(.chrome))
                        .foregroundStyle(Color.inwardPaper)
                        .padding(.horizontal, Lamplight.Spacing.block)
                        .padding(.vertical, Lamplight.Spacing.element)
                        .background(Capsule().fill(Color.inwardClay))
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Lamplight.Spacing.block)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.inwardPaper.ignoresSafeArea())
    }
}
