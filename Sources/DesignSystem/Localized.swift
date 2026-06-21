import Foundation

/// Lightweight, dependency-free localization for the centralized `Copy` strings.
///
/// Resolves the device's preferred language to one of the supported translation
/// tables and falls back to the English default baked into each `t(_:_:)` call.
/// Kept as plain Swift (rather than a String Catalog) so every translation is
/// compiler-checked and the test suite can assert completeness across all nine
/// languages — quality still wants native review, but nothing can silently go missing.
public enum Localized {
    /// Supported translation tables, keyed by ISO language code. English is the
    /// in-code default (the second argument to `t`), so it isn't a table here.
    static let tables: [String: [String: String]] = [
        "de": Translations.de,
        "fr": Translations.fr,
        "it": Translations.it,
        "pt": Translations.pt,
        "es": Translations.es,
        "nb": Translations.nb,
        "sv": Translations.sv,
        "da": Translations.da,
        "ru": Translations.ru,
    ]

    /// The localized string for `key`, or `english` when there's no translation
    /// (unsupported language, or a key the active table doesn't cover).
    public static func t(_ key: String, _ english: String) -> String {
        guard let code = activeCode, let value = tables[code]?[key] else { return english }
        return value
    }

    /// The first of the user's preferred languages we have a table for; nil means
    /// English (the in-code default). Norwegian variants map to Bokmål.
    static var activeCode: String? {
        for identifier in Locale.preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier
                ?? String(identifier.prefix(2))
            if code == "en" { return nil }
            if tables[code] != nil { return code }
            if code == "no" || code == "nn" { return tables["nb"] != nil ? "nb" : nil }
        }
        return nil
    }
}
