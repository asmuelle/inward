import Foundation
@testable import SafetyKit
import Testing

@Suite("CrisisGate — additive localization across the supported languages")
struct CrisisGateLocalizationTests {
    /// One representative self-harm phrasing per supported language.
    static let localizedSelfHarm: [(code: String, text: String)] = [
        ("de", "Manchmal will ich mich einfach umbringen."),
        ("fr", "Certains jours, je veux mourir."),
        ("it", "A volte voglio morire."),
        ("pt", "Às vezes quero morrer."),
        ("es", "A veces quiero morir."),
        ("nb", "Noen dager vil jeg dø."),
        ("sv", "Vissa dagar vill jag dö."),
        ("da", "Nogle dage vil jeg dø."),
        ("ru", "Иногда я хочу умереть."),
    ]

    static let allCodes = ["en", "de", "fr", "it", "pt", "es", "nb", "sv", "da", "ru"]

    @Test("a localized self-harm phrase trips the gate", arguments: localizedSelfHarm)
    func localizedPhraseMatches(sample: (code: String, text: String)) {
        let gate = CrisisGate(localizedFor: Locale(identifier: sample.code))
        let decision = gate.evaluate(sample.text)

        guard case let .matched(matches, resources) = decision else {
            Issue.record("\(sample.code) should have matched: \(sample.text)")
            return
        }
        #expect(matches.contains { $0.category == .selfHarm })
        #expect(!resources.isEmpty)
    }

    @Test("English still matches under a localized gate (additive, never replaced)", arguments: localizedSelfHarm.map(\.code))
    func englishStillMatchesUnderLocalizedGate(code: String) {
        let gate = CrisisGate(localizedFor: Locale(identifier: code))
        #expect(gate.evaluate("I want to die").isMatched, "\(code) lost the English floor")
    }

    @Test("the English locale is unchanged — same lexicon and bundled resources")
    func englishIsUnchanged() {
        #expect(CrisisLexicon.merged(forLanguage: "en") == CrisisLexicon.english)
        #expect(CrisisLexicon.merged(forLanguage: nil) == CrisisLexicon.english)
        #expect(SupportResource.localized(for: Locale(identifier: "en_US")) == SupportResource.bundled)

        let gate = CrisisGate(localizedFor: Locale(identifier: "en_US"))
        guard case let .matched(_, resources) = gate.evaluate("I want to die") else {
            Issue.record("English gate should match")
            return
        }
        #expect(resources == SupportResource.bundled)
    }

    @Test("merging keeps the English phrases and adds the localized ones")
    func mergingIsAdditive() {
        let merged = CrisisLexicon.merged(forLanguage: "de")
        let selfHarm = merged[.selfHarm] ?? []
        #expect(selfHarm.contains("kill myself"), "English phrase must survive the merge")
        #expect(selfHarm.contains("mich umbringen"), "localized phrase must be added")
    }

    @Test("every supported locale carries non-empty, well-formed resources", arguments: allCodes)
    func resourcesAreNeverEmpty(code: String) {
        let resources = SupportResource.localized(for: Locale(identifier: code))
        #expect(!resources.isEmpty, "\(code) has no support resources")
        #expect(resources.allSatisfy { !$0.name.isEmpty && !$0.detail.isEmpty }, "\(code) has a blank resource")
        // Ids must be unique within a locale's set.
        #expect(Set(resources.map(\.id)).count == resources.count, "\(code) has duplicate resource ids")
    }

    @Test("clear text stays clear under a localized gate")
    func clearTextStaysClear() {
        let gate = CrisisGate(localizedFor: Locale(identifier: "de"))
        #expect(gate.evaluate("Ruhiger Morgen, Kaffee auf dem Balkon.") == .clear)
    }
}
