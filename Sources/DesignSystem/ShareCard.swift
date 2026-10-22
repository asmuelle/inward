#if canImport(SwiftUI)
    import CoreGraphics
    import SwiftUI

    /// Share cards: the one thing Inward lets a user emit. Everything here is a
    /// rendered picture — never a link, never an upload, never a network call. The
    /// card is composed on device, handed to the system share sheet, and where it
    /// goes from there is the user's choice alone.
    ///
    /// Invariant: a card carries only what the user can see in the preview before
    /// sending. No entry text, no transcripts, no identifiers.
    public extension Lamplight {
        enum ShareCard {
            /// 4:5 portrait — the ratio that survives feed cropping where people
            /// actually paste pictures. Rendered at pixel size, scale 1.
            public static let size = CGSize(width: 1080, height: 1350)
            /// Generous margins: the card should read as a printed page, not a
            /// screenshot that happens to be square.
            public static let margin: Double = 96
            /// Hairline rule inset from the edge — the "pressed page" frame.
            public static let ruleInset: Double = 44
        }

        /// Type scale for the card, which is ~5x the size of a phone surface and
        /// so needs its own steps rather than scaled UI roles.
        enum ShareCardType: Sendable, Equatable {
            case headline
            case body
            case word
            case caption

            public var pointSize: Double {
                switch self {
                case .headline: 86
                case .body: 44
                case .word: 58
                case .caption: 32
                }
            }

            public var usesSerif: Bool {
                switch self {
                case .headline, .body, .word: true
                case .caption: false
                }
            }
        }
    }

    public extension Font {
        /// The card type scale — same two-family rule as the app surfaces.
        static func shareCard(_ step: Lamplight.ShareCardType) -> Font {
            step.usesSerif
                ? .system(size: step.pointSize, weight: step == .headline ? .semibold : .regular, design: .serif)
                : .system(size: step.pointSize, weight: .regular, design: .default)
        }
    }

    /// The shared page every card is printed on: warm paper, a lamplight vignette,
    /// a hairline rule, and the wordmark footer that makes the picture legible as
    /// "this came from Inward" without a logo file.
    public struct ShareCardCanvas<Content: View>: View {
        private let content: Content

        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        public var body: some View {
            ZStack {
                Color.inwardPaper
                // Lamplight, not a spotlight: the page is warmer at the top-left
                // where the lamp would be, falling off into the corner.
                RadialGradient(
                    colors: [Color.inwardShadowTint.opacity(0.0), Color.inwardShadowTint.opacity(0.16)],
                    center: UnitPoint(x: 0.34, y: 0.28),
                    startRadius: Lamplight.ShareCard.size.width * 0.18,
                    endRadius: Lamplight.ShareCard.size.width * 1.05
                )
                RoundedRectangle(cornerRadius: Lamplight.Surface.cardRadius * 2, style: .continuous)
                    .strokeBorder(Color.inwardShadowTint.opacity(0.22), lineWidth: 2)
                    .padding(Lamplight.ShareCard.ruleInset)

                VStack(alignment: .leading, spacing: Lamplight.Spacing.section) {
                    // The card is taller than any card's content, so the content
                    // takes the slack and distributes it itself — otherwise every
                    // card reads as text jammed against a void.
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    wordmark
                }
                .padding(Lamplight.ShareCard.margin)
                .frame(
                    width: Lamplight.ShareCard.size.width,
                    height: Lamplight.ShareCard.size.height,
                    alignment: .topLeading
                )
            }
            .frame(width: Lamplight.ShareCard.size.width, height: Lamplight.ShareCard.size.height)
        }

        private var wordmark: some View {
            HStack(spacing: Lamplight.Spacing.element) {
                Circle()
                    .fill(Color.inwardClay)
                    .frame(width: 26, height: 26)
                Text(Copy.shareWordmark)
                    .font(.shareCard(.caption))
                    .foregroundStyle(Color.inwardSage)
            }
        }
    }

    /// The privacy proof as a picture: the claim, the live offline state at the
    /// moment it was made, and nothing else. Every line must stay literally true —
    /// this card is the product's central claim leaving the phone in public.
    public struct ProofShareCard: View {
        private let isOffline: Bool

        public init(isOffline: Bool) {
            self.isOffline = isOffline
        }

        public var body: some View {
            ShareCardCanvas {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
                    HStack(spacing: Lamplight.Spacing.element) {
                        Image(systemName: isOffline ? "airplane" : "lock.fill")
                            .font(.system(size: Lamplight.ShareCardType.body.pointSize))
                            .foregroundStyle(Color.inwardClay)
                        Text(isOffline ? Copy.shareProofOffline : Copy.shareProofOnline)
                            .font(.shareCard(.caption))
                            .tracking(1.4)
                            .foregroundStyle(Color.inwardSage)
                    }
                    Spacer(minLength: 0)
                    Text(Copy.shareProofHeadline)
                        .font(.shareCard(.headline))
                        .foregroundStyle(Color.inwardInk)
                        .lineSpacing(Lamplight.ShareCardType.headline.pointSize * 0.18)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Copy.shareProofBody)
                        .font(.shareCard(.body))
                        .foregroundStyle(Color.inwardInk.opacity(0.78))
                        .lineSpacing(Lamplight.ShareCardType.body.pointSize * 0.32)
                        .fixedSize(horizontal: false, vertical: true)
                        // The headline's own line spacing closes the VStack gap.
                        .padding(.top, Lamplight.Spacing.element)
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    /// The week as a handful of words. Theme words only — never an observation,
    /// never a sentence the user wrote. That restraint is what makes this card
    /// safe to post, and it happens to be the better-looking card.
    public struct ThemesShareCard: View {
        /// Cards past five words stop reading as a poster and start reading as a
        /// list; the extra themes stay in the app.
        public nonisolated static let maxThemes = 5

        private let themes: [String]
        private let dateRange: String

        public init(themes: [String], dateRange: String) {
            self.themes = Self.displayed(themes)
            self.dateRange = dateRange
        }

        /// The words that make it onto the card: trimmed, blank-free, and capped.
        /// Pure, so the restraint is testable without rasterizing anything —
        /// `nonisolated` because `View` conformance would otherwise pin it to
        /// the main actor and trap when tests call it off one.
        public nonisolated static func displayed(_ themes: [String]) -> [String] {
            themes
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(maxThemes)
                .map(\.self)
        }

        public var body: some View {
            ShareCardCanvas {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
                    Text(dateRange)
                        .font(.shareCard(.caption))
                        .tracking(1.4)
                        .foregroundStyle(Color.inwardSage)
                    Text(Copy.weeklyThemesHeader)
                        .font(.shareCard(.body))
                        .foregroundStyle(Color.inwardInk.opacity(0.7))
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: Lamplight.Spacing.element) {
                        ForEach(Array(themes.enumerated()), id: \.offset) { _, theme in
                            HStack(alignment: .firstTextBaseline, spacing: Lamplight.Spacing.element) {
                                Circle()
                                    .fill(Color.inwardClay.opacity(0.55))
                                    .frame(width: 14, height: 14)
                                Text(theme)
                                    .font(.shareCard(.word))
                                    .foregroundStyle(Color.inwardInk)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                    }
                    .padding(.top, Lamplight.Spacing.element)
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    /// Renders a card to a picture on the main actor. Returns nil rather than
    /// crashing when the platform declines to rasterize — a missing share button
    /// is a far better failure than a dead app.
    @MainActor
    public enum ShareCardRenderer {
        /// The rasterized card, or nil if rendering failed.
        public static func cgImage(_ card: some View) -> CGImage? {
            let renderer = ImageRenderer(content: card)
            // The canvas is already laid out at pixel size, so no upscaling.
            renderer.scale = 1
            renderer.isOpaque = true
            return renderer.cgImage
        }

        /// The card as a SwiftUI `Image`, ready for `ShareLink` (which transfers
        /// it as a picture — no file is written to disk on the way out).
        public static func image(_ card: some View) -> Image? {
            guard let cgImage = cgImage(card) else { return nil }
            return Image(decorative: cgImage, scale: 1)
        }
    }
#endif
