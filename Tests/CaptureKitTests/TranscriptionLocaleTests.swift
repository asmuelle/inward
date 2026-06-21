import CaptureKit
import Foundation
import Testing

/// The supported set mirrors SpeechTranscriber.supportedLocales shape: region-specific.
private let supported = [
    "en-US", "en-GB", "en-AU", "en-CA", "en-IN",
    "de-DE", "de-AT", "de-CH",
    "fr-FR", "es-ES",
].map(Locale.init(identifier:))

@Suite("TranscriptionLocale — match the user's locale to a supported one")
struct TranscriptionLocaleTests {
    @Test("an exact region match is preferred")
    func exactMatch() {
        let result = TranscriptionLocale.bestMatch(for: Locale(identifier: "en-GB"), among: supported)
        #expect(result?.identifier(.bcp47) == "en-GB")
    }

    @Test("en-DE falls back to a supported English locale instead of failing")
    func englishRegionFallback() {
        // The real-world bug: English language, German region — not an enumerated
        // dictation locale, but English transcription must still be offered.
        let result = TranscriptionLocale.bestMatch(for: Locale(identifier: "en-DE"), among: supported)
        #expect(result?.language.languageCode?.identifier == "en")
    }

    @Test("same language + same region wins over a different region")
    func prefersSameRegion() {
        // de-CH is present; a user in de-CH should get de-CH, not de-DE.
        let result = TranscriptionLocale.bestMatch(for: Locale(identifier: "de-CH"), among: supported)
        #expect(result?.identifier(.bcp47) == "de-CH")
    }

    @Test("an unsupported language returns nil")
    func unsupportedLanguage() {
        let result = TranscriptionLocale.bestMatch(for: Locale(identifier: "ja-JP"), among: supported)
        #expect(result == nil)
    }

    @Test("an empty supported set returns nil")
    func emptySupported() {
        #expect(TranscriptionLocale.bestMatch(for: Locale(identifier: "en-US"), among: []) == nil)
    }
}
