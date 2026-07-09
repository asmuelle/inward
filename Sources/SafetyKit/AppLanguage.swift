import Foundation

/// The single source of truth for which language Inward listens in, reads back,
/// and generates in. Every on-device surface — the ASR locale, the spoken-recap
/// voice, and the on-device model's output — resolves its language here, so a note
/// spoken in German is transcribed, read back, and reviewed in German rather than
/// slipping into English.
///
/// The choice is a device-only preference (a language code in `UserDefaults`, or
/// absent to follow the phone) — journal content, not user data. It lives in
/// SafetyKit because that is the one module the capture, reflection, and insight
/// providers already share, so all three can pin the model's output language
/// without a new dependency.
public enum AppLanguage {
    /// `UserDefaults` key holding the selected language code, or `systemValue` /
    /// absent to follow the device. Shared verbatim with the Settings picker.
    public static let preferenceKey = "inward.languageCode"

    /// The stored value that means "follow the device language".
    public static let systemValue = "system"

    /// The languages Inward ships end to end — UI copy *and* model prompting — in
    /// menu order. English leads; the rest mirror the DesignSystem translation
    /// tables so the whole experience stays consistent in the chosen language.
    public static let supportedCodes = ["en", "de", "fr", "it", "pt", "es", "nb", "sv", "da", "ru"]

    /// The explicitly chosen language code, or nil when following the device.
    public static func selection(_ defaults: UserDefaults = .standard) -> String? {
        guard let raw = defaults.string(forKey: preferenceKey),
              raw != systemValue, !raw.isEmpty
        else { return nil }
        return raw
    }

    /// The language every on-device surface should use right now. Following the
    /// device keeps the full regional `Locale.current` (so today's behavior is
    /// unchanged); an explicit choice yields the bare language, which the
    /// transcriber's `bestMatch` maps onto an installed regional model.
    public static func resolved(_ defaults: UserDefaults = .standard) -> ResolvedLanguage {
        guard let code = selection(defaults) else {
            let deviceCode = Locale.current.language.languageCode?.identifier ?? "en"
            return ResolvedLanguage(code: deviceCode, locale: .current, isSystem: true)
        }
        return ResolvedLanguage(code: code, locale: Locale(identifier: code), isSystem: false)
    }

    /// The language's name in itself ("Deutsch", "Français") for the picker — the
    /// clearest label for someone choosing their own language.
    public static func endonym(for code: String) -> String {
        Locale(identifier: code).localizedString(forLanguageCode: code)?.capitalized ?? code
    }
}

/// A resolved language, ready to hand to the transcriber, the synthesizer, and the
/// on-device model.
public struct ResolvedLanguage: Sendable, Equatable {
    /// ISO 639 language code, e.g. "de".
    public let code: String
    /// The locale to transcribe and synthesize in.
    public let locale: Locale
    /// True when following the device rather than an explicit choice.
    public let isSystem: Bool

    public init(code: String, locale: Locale, isSystem: Bool) {
        self.code = code
        self.locale = locale
        self.isSystem = isSystem
    }

    /// The language's English name ("German", "French"), used to instruct the
    /// on-device model. English is the reliable metalanguage for the directive.
    public var englishName: String {
        Locale(identifier: "en").localizedString(forLanguageCode: code)?.capitalized ?? code
    }

    /// The instruction that pins the model's output language. Without it Apple's
    /// on-device model tends to answer in the language of its (English) system
    /// prompt, so a German note comes back as an English recap read aloud by the
    /// German voice. Prepended to every provider's instructions.
    public var modelInstruction: String {
        "Always write your entire reply in \(englishName). "
            + "Even if the note or these instructions appear in another language, respond only in \(englishName)."
    }
}
