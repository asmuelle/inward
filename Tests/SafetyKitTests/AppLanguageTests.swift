import Foundation
@testable import SafetyKit
import Testing

@Suite("AppLanguage — resolves one language for every on-device surface")
struct AppLanguageTests {
    /// A defaults suite scoped to each test so nothing leaks into `.standard`.
    private func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("no stored choice follows the device and keeps the regional locale")
    func followsDeviceByDefault() {
        let resolved = AppLanguage.resolved(makeDefaults())
        #expect(resolved.isSystem)
        #expect(resolved.locale == .current)
    }

    @Test("the system sentinel is treated as no choice")
    func systemSentinelFollowsDevice() {
        let defaults = makeDefaults()
        defaults.set(AppLanguage.systemValue, forKey: AppLanguage.preferenceKey)
        #expect(AppLanguage.selection(defaults) == nil)
        #expect(AppLanguage.resolved(defaults).isSystem)
    }

    @Test("an explicit choice yields the bare-language locale and English name")
    func explicitChoiceResolves() {
        let defaults = makeDefaults()
        defaults.set("de", forKey: AppLanguage.preferenceKey)
        let resolved = AppLanguage.resolved(defaults)
        #expect(!resolved.isSystem)
        #expect(resolved.code == "de")
        #expect(resolved.locale.language.languageCode?.identifier == "de")
        #expect(resolved.englishName == "German")
    }

    @Test("the model instruction names the language on both sides")
    func modelInstructionPinsLanguage() {
        let resolved = ResolvedLanguage(code: "de", locale: Locale(identifier: "de"), isSystem: false)
        #expect(resolved.modelInstruction.contains("German"))
        // The whole point: the model must not fall back to its English prompt.
        #expect(resolved.modelInstruction.contains("respond only in German"))
    }

    @Test("every shipped language has a usable endonym")
    func endonymsResolve() {
        for code in AppLanguage.supportedCodes {
            #expect(!AppLanguage.endonym(for: code).isEmpty)
        }
        #expect(AppLanguage.endonym(for: "de") == "Deutsch")
    }
}
