@testable import DesignSystem
import Testing

@Suite("Lamplight tokens")
struct LamplightTokenTests {
    @Test("every palette token parses as #RRGGBB")
    func paletteParses() {
        for token in Lamplight.Palette.all {
            #expect(token.rgb != nil, "malformed token: \(token.name) \(token.hex)")
        }
    }

    @Test("the dark surface is lamplight, never pure black")
    func darkSurfaceIsWarm() throws {
        // Arrange
        let rgb = try #require(Lamplight.Palette.lamplight.rgb)

        // Assert — warm: red leads green leads blue; and clearly above pure black
        #expect(rgb.red > rgb.green)
        #expect(rgb.green > rgb.blue)
        #expect(rgb.red > 0.05)
    }

    @Test("paper and ink keep readable contrast (relative luminance gap)")
    func paperInkContrast() throws {
        // Arrange
        let paper = try #require(Lamplight.Palette.paper.rgb)
        let ink = try #require(Lamplight.Palette.ink.rgb)

        func luminance(_ rgb: (red: Double, green: Double, blue: Double)) -> Double {
            0.2126 * rgb.red + 0.7152 * rgb.green + 0.0722 * rgb.blue
        }

        // Assert — generous gap between surface and text
        #expect(luminance(paper) - luminance(ink) > 0.5)
    }

    @Test("malformed hex degrades to nil, not a crash")
    func malformedHexIsNil() {
        #expect(Lamplight.ColorToken(name: "bad", hex: "#XYZXYZ").rgb == nil)
        #expect(Lamplight.ColorToken(name: "short", hex: "#FFF").rgb == nil)
    }

    @Test("motion stays at breathing pace per the design direction")
    func motionIsBreathingPace() {
        #expect(Lamplight.Motion.standard >= 0.3)
        #expect(Lamplight.Motion.unhurried <= 0.45)
    }

    @Test("prose roles use serif with generous line height; chrome does not")
    func typographyRoles() {
        #expect(Lamplight.TypeRole.entryProse.usesSerif)
        #expect(Lamplight.TypeRole.entryProse.lineSpacingMultiplier >= 1.5)
        #expect(!Lamplight.TypeRole.chrome.usesSerif)
    }
}

@Suite("Copy")
struct CopyTests {
    @Test("every user-facing string is present and non-empty")
    func copyComplete() {
        #expect(!Copy.allStrings.isEmpty)
        #expect(Copy.allStrings.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
}
