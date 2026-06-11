import Foundation

/// The Lamplight-paper design language: warm analog stationery, never a sterile dashboard.
/// All visual decisions flow from these tokens; no surface hardcodes its own values.
public enum Lamplight {
    // MARK: - Color tokens (hex, resolved to platform colors in Color+Token.swift)

    public struct ColorToken: Sendable, Equatable {
        public let name: String
        public let hex: String

        public init(name: String, hex: String) {
            self.name = name
            self.hex = hex
        }

        /// Parses `#RRGGBB` into 0...1 components. Returns nil for malformed tokens.
        public var rgb: (red: Double, green: Double, blue: Double)? {
            let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
            return (
                red: Double((value >> 16) & 0xFF) / 255.0,
                green: Double((value >> 8) & 0xFF) / 255.0,
                blue: Double(value & 0xFF) / 255.0
            )
        }
    }

    public enum Palette {
        /// Unbleached warm paper — the light surface.
        public static let paper = ColorToken(name: "paper", hex: "#F7F2E9")
        /// Ink charcoal — primary text on paper.
        public static let ink = ColorToken(name: "ink", hex: "#2B2620")
        /// Muted clay — the record button and primary calls to action.
        public static let clay = ColorToken(name: "clay", hex: "#B5654A")
        /// Dried sage — themes and quiet metadata.
        public static let sage = ColorToken(name: "sage", hex: "#7C8471")
        /// Lamplight — the dark surface: warm brown-charcoal, never pure black.
        public static let lamplight = ColorToken(name: "lamplight", hex: "#211D18")
        /// Amber-shifted text for the lamplight (dark) theme.
        public static let amberText = ColorToken(name: "amberText", hex: "#E9DFC9")
        /// Soft warm shadow tint for layered cards.
        public static let shadowTint = ColorToken(name: "shadowTint", hex: "#5C4F3E")

        public static let all: [ColorToken] = [paper, ink, clay, sage, lamplight, amberText, shadowTint]
    }

    // MARK: - Spacing (intentional rhythm, not uniform padding)

    public enum Spacing {
        public static let hairline: Double = 2
        public static let tight: Double = 6
        public static let element: Double = 12
        public static let block: Double = 20
        public static let section: Double = 34
        public static let stage: Double = 56
    }

    // MARK: - Radii & depth

    public enum Surface {
        public static let cardRadius: Double = 14
        public static let sheetRadius: Double = 22
        public static let cardShadowRadius: Double = 18
        public static let cardShadowOpacity: Double = 0.10
    }

    // MARK: - Motion (breathing pace; everything respects Reduce Motion)

    public enum Motion {
        /// Seconds. Breathing-pace transitions per DESIGN.md: 300-450ms, ease-out.
        public static let standard: Double = 0.34
        public static let unhurried: Double = 0.45
        public static let waveformPulse: Double = 1.2
    }

    // MARK: - Typography roles (two families only: serif for words, system for chrome)

    public enum TypeRole: Sendable, Equatable {
        /// Entry text, reflections, review prose — serif, generous size, 1.5+ line height.
        case entryProse
        /// Titles in the journal voice.
        case journalTitle
        /// Chrome: labels, buttons, metadata.
        case chrome
        /// Tiny quiet metadata (dates, durations).
        case caption

        public var pointSize: Double {
            switch self {
            case .entryProse: 19
            case .journalTitle: 28
            case .chrome: 15
            case .caption: 12
            }
        }

        public var lineSpacingMultiplier: Double {
            switch self {
            case .entryProse: 1.55
            case .journalTitle: 1.3
            case .chrome, .caption: 1.2
            }
        }

        public var usesSerif: Bool {
            switch self {
            case .entryProse, .journalTitle: true
            case .chrome, .caption: false
            }
        }
    }
}
