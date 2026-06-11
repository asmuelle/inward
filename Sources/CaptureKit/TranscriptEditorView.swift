#if canImport(SwiftUI)
    import DesignSystem
    import SwiftUI

    /// "Read it back" — inline edit of the transcript before keeping it. Serif
    /// entry typography on a paper card; keep/discard, nothing else.
    public struct TranscriptEditorView: View {
        @State private var text: String
        private let onChange: (String) -> Void
        private let onKeep: () -> Void
        private let onDiscard: () -> Void

        public init(
            draft: String,
            onChange: @escaping (String) -> Void,
            onKeep: @escaping () -> Void,
            onDiscard: @escaping () -> Void
        ) {
            _text = State(initialValue: draft)
            self.onChange = onChange
            self.onKeep = onKeep
            self.onDiscard = onDiscard
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
                Text(Copy.readItBack)
                    .font(.lamplight(.journalTitle))
                    .foregroundStyle(Color.inwardInk)

                PaperCard {
                    TextEditor(text: $text)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .onChange(of: text) { onChange(text) }
                }

                HStack(spacing: Lamplight.Spacing.block) {
                    Button(Copy.discardEntry, action: onDiscard)
                        .font(.lamplight(.chrome))
                        .foregroundStyle(Color.inwardSage)

                    Spacer()

                    Button(action: onKeep) {
                        Text(Copy.keepEntry)
                            .font(.lamplight(.chrome))
                            .foregroundStyle(Color.inwardPaper)
                            .padding(.horizontal, Lamplight.Spacing.block)
                            .padding(.vertical, Lamplight.Spacing.element)
                            .background(
                                Capsule().fill(Color.inwardClay)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
#endif
