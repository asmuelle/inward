#if canImport(SwiftUI)
    import SwiftUI

    public extension Color {
        /// Resolves a Lamplight color token. Malformed tokens degrade to ink charcoal
        /// rather than crashing — a wrong shade is better than a dead app.
        init(token: Lamplight.ColorToken) {
            let rgb = token.rgb ?? (red: 0.17, green: 0.15, blue: 0.13)
            self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
        }

        static let inwardPaper = Color(token: Lamplight.Palette.paper)
        static let inwardInk = Color(token: Lamplight.Palette.ink)
        static let inwardClay = Color(token: Lamplight.Palette.clay)
        static let inwardSage = Color(token: Lamplight.Palette.sage)
        static let inwardLamplight = Color(token: Lamplight.Palette.lamplight)
        static let inwardAmberText = Color(token: Lamplight.Palette.amberText)
        static let inwardShadowTint = Color(token: Lamplight.Palette.shadowTint)
    }

    public extension Font {
        /// The two-family rule: New York (system serif) for words, SF Pro for chrome.
        static func lamplight(_ role: Lamplight.TypeRole) -> Font {
            let size = role.pointSize
            return role.usesSerif
                ? .system(size: size, weight: role == .journalTitle ? .semibold : .regular, design: .serif)
                : .system(size: size, weight: .regular, design: .default)
        }
    }
#endif
