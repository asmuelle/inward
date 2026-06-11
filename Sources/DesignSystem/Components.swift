#if canImport(SwiftUI)
    import SwiftUI

    /// The single strongest element on the home surface: a clay circle that breathes
    /// while recording. Respects Reduce Motion by holding still.
    public struct RecordButton: View {
        public let isRecording: Bool
        public let action: () -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var pulsing = false

        public init(isRecording: Bool, action: @escaping () -> Void) {
            self.isRecording = isRecording
            self.action = action
        }

        public var body: some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.inwardClay.opacity(0.22))
                        .frame(width: 92, height: 92)
                        .scaleEffect(pulsing && !reduceMotion ? 1.12 : 1.0)
                    Circle()
                        .fill(Color.inwardClay)
                        .frame(width: 72, height: 72)
                        .shadow(
                            color: Color.inwardShadowTint.opacity(Lamplight.Surface.cardShadowOpacity * 2),
                            radius: Lamplight.Surface.cardShadowRadius / 2, y: 4
                        )
                    recordGlyph
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecording ? Copy.stopAccessibility : Copy.recordAccessibility)
            .onAppear { startPulseIfNeeded() }
            .onChange(of: isRecording) { startPulseIfNeeded() }
        }

        @ViewBuilder private var recordGlyph: some View {
            if isRecording {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.inwardPaper)
                    .frame(width: 24, height: 24)
            } else {
                Circle()
                    .fill(Color.inwardPaper.opacity(0.92))
                    .frame(width: 26, height: 26)
            }
        }

        private func startPulseIfNeeded() {
            guard isRecording, !reduceMotion else {
                pulsing = false
                return
            }
            withAnimation(.easeOut(duration: Lamplight.Motion.waveformPulse).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }

    /// A layered paper card with a soft warm shadow — the standard entry surface.
    public struct PaperCard<Content: View>: View {
        private let content: Content

        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        public var body: some View {
            content
                .padding(Lamplight.Spacing.block)
                .background(
                    RoundedRectangle(cornerRadius: Lamplight.Surface.cardRadius, style: .continuous)
                        .fill(Color.inwardPaper)
                        .shadow(
                            color: Color.inwardShadowTint.opacity(Lamplight.Surface.cardShadowOpacity),
                            radius: Lamplight.Surface.cardShadowRadius, y: 6
                        )
                )
        }
    }
#endif
