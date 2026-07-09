@testable import DesignSystem
import Testing

@Suite("Localized — the app can pin one language regardless of the device")
struct LocalizedOverrideTests {
    /// Global override, so each test restores it rather than leaking a language.
    private func withOverride(_ code: String?, _ body: () -> Void) {
        let previous = Localized.override
        Localized.override = code
        defer { Localized.override = previous }
        body()
    }

    @Test("an explicit code pins copy to that table")
    func explicitCodePins() {
        withOverride("de") {
            #expect(Localized.t("settingsLanguageTitle", "Language") == "Sprache")
        }
    }

    @Test("English pins the in-code default even on a translated device key")
    func englishPinsDefault() {
        withOverride("en") {
            #expect(Localized.t("settingsLanguageTitle", "Language") == "Language")
        }
    }

    @Test("an unsupported code falls back to English rather than crashing")
    func unsupportedFallsBack() {
        withOverride("zz") {
            #expect(Localized.t("settingsLanguageTitle", "Language") == "Language")
        }
    }
}
