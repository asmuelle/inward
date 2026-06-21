import Foundation

/// Maps the user's locale onto a locale the on-device transcriber actually
/// supports. The supported set is region-specific (e.g. en-US, en-GB, de-DE),
/// so a user whose locale is a region the model doesn't enumerate — `en-DE`
/// (English language, German region) is the common case — must still get English
/// transcription instead of being told voice is unavailable.
///
/// Pure and Speech-framework-free so the matching is unit-testable on any platform.
public enum TranscriptionLocale {
    /// The supported locale that best fits `preferred`:
    /// 1. an exact BCP-47 match, else
    /// 2. a supported locale sharing the language *and* region, else
    /// 3. any supported locale sharing the language.
    /// Returns nil only when the language itself isn't supported at all.
    public static func bestMatch(for preferred: Locale, among supported: [Locale]) -> Locale? {
        let preferredID = preferred.identifier(.bcp47)
        if let exact = supported.first(where: { $0.identifier(.bcp47) == preferredID }) {
            return exact
        }
        guard let language = preferred.language.languageCode?.identifier else { return nil }
        let sameLanguage = supported.filter { $0.language.languageCode?.identifier == language }
        if let region = preferred.region?.identifier {
            let sameRegion = sameLanguage.first { $0.region?.identifier == region }
            if let sameRegion { return sameRegion }
        }
        return sameLanguage.first
    }
}
