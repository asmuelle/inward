import Foundation

/// Region-appropriate support resources, additive to the English/US `bundled` set.
///
/// Deliberately conservative: rather than hardcode national hotline numbers that
/// can be wrong or go stale (worse than no number in a crisis), each localized set
/// points to findahelpline.com — which routes to the user's own country's crisis
/// lines — plus the IASP international directory, and 112 only where it is
/// unambiguously the emergency number. Verified national lines can be added per
/// region as a sourcing pass. Copy is machine-drafted; flagged for native review.
extension SupportResource {
    /// Region-appropriate resources for `locale`. English (and anything without a
    /// localized set) returns the US/English `bundled` list. Never empty — the
    /// finder and the international directory always apply.
    public static func localized(for locale: Locale) -> [SupportResource] {
        let code = locale.language.languageCode?.identifier ?? "en"
        switch code {
        case "de": return german
        case "fr": return french
        case "it": return italian
        case "pt": return portuguese
        case "es": return spanish
        case "nb": return norwegian
        case "sv": return swedish
        case "da": return danish
        case "ru": return russian
        default: return bundled
        }
    }

    /// 112 is the single emergency number across the EU/EEA and Russia, so it is
    /// safe to surface for those locales. Built per language so the framing is in
    /// the reader's own words.
    private static func emergency112(id: String, name: String, detail: String) -> SupportResource {
        SupportResource(id: id, name: name, detail: detail, region: "Europe")
    }

    private static func findHelpline(id: String, name: String, detail: String, region: String) -> SupportResource {
        SupportResource(id: id, name: name, detail: detail, region: region)
    }

    private static func iasp(id: String, name: String, detail: String) -> SupportResource {
        SupportResource(id: id, name: name, detail: detail, region: "International")
    }

    static let german: [SupportResource] = [
        emergency112(
            id: "de-112",
            name: "Notruf 112",
            detail: "Bei unmittelbarer Gefahr ruf 112 — die Notrufnummer in ganz Europa."
        ),
        findHelpline(
            id: "de-findahelpline",
            name: "Finde eine Krisenberatung",
            detail: "Finde eine Beratungsstelle in deinem Land auf findahelpline.com.",
            region: "DE"
        ),
        iasp(
            id: "de-iasp",
            name: "Krisenzentrum in deiner Nähe",
            detail: "Die IASP führt ein Verzeichnis unter iasp.info/resources/Crisis_Centres."
        ),
    ]

    static let french: [SupportResource] = [
        emergency112(
            id: "fr-112",
            name: "Numéro d’urgence 112",
            detail: "En cas de danger immédiat, appelle le 112 — le numéro d’urgence partout en Europe."
        ),
        findHelpline(
            id: "fr-findahelpline",
            name: "Trouver une ligne d’écoute",
            detail: "Trouve une ligne d’écoute dans ton pays sur findahelpline.com.",
            region: "FR"
        ),
        iasp(
            id: "fr-iasp",
            name: "Un centre de crise près de chez toi",
            detail: "L’IASP tient un annuaire sur iasp.info/resources/Crisis_Centres."
        ),
    ]

    static let italian: [SupportResource] = [
        emergency112(
            id: "it-112",
            name: "Numero di emergenza 112",
            detail: "In caso di pericolo immediato chiama il 112 — il numero di emergenza in tutta Europa."
        ),
        findHelpline(
            id: "it-findahelpline",
            name: "Trova una linea di ascolto",
            detail: "Trova una linea di ascolto nel tuo paese su findahelpline.com.",
            region: "IT"
        ),
        iasp(
            id: "it-iasp",
            name: "Un centro di crisi vicino a te",
            detail: "L’IASP tiene un elenco su iasp.info/resources/Crisis_Centres."
        ),
    ]

    static let portuguese: [SupportResource] = [
        findHelpline(
            id: "pt-findahelpline",
            name: "Encontra uma linha de apoio",
            detail: "Encontra uma linha de apoio no teu país em findahelpline.com.",
            region: "PT"
        ),
        iasp(
            id: "pt-iasp",
            name: "Um centro de crise perto de ti",
            detail: "A IASP mantém um diretório em iasp.info/resources/Crisis_Centres."
        ),
    ]

    static let spanish: [SupportResource] = [
        findHelpline(
            id: "es-findahelpline",
            name: "Encuentra una línea de ayuda",
            detail: "Encuentra una línea de ayuda en tu país en findahelpline.com.",
            region: "ES"
        ),
        iasp(
            id: "es-iasp",
            name: "Un centro de crisis cerca de ti",
            detail: "La IASP mantiene un directorio en iasp.info/resources/Crisis_Centres."
        ),
    ]

    static let norwegian: [SupportResource] = [
        emergency112(
            id: "nb-112",
            name: "Nødnummer 112",
            detail: "Ved umiddelbar fare, ring 112 — nødnummeret i hele Europa."
        ),
        findHelpline(
            id: "nb-findahelpline",
            name: "Finn en hjelpetelefon",
            detail: "Finn en hjelpetelefon i landet ditt på findahelpline.com.",
            region: "NO"
        ),
        iasp(
            id: "nb-iasp",
            name: "Et krisesenter nær deg",
            detail: "IASP har en oversikt på iasp.info/resources/Crisis_Centres."
        ),
    ]

    static let swedish: [SupportResource] = [
        emergency112(
            id: "sv-112",
            name: "Nödnummer 112",
            detail: "Vid omedelbar fara, ring 112 — nödnumret i hela Europa."
        ),
        findHelpline(
            id: "sv-findahelpline",
            name: "Hitta en stödlinje",
            detail: "Hitta en stödlinje i ditt land på findahelpline.com.",
            region: "SE"
        ),
        iasp(
            id: "sv-iasp",
            name: "Ett kriscentrum nära dig",
            detail: "IASP har en katalog på iasp.info/resources/Crisis_Centres."
        ),
    ]

    static let danish: [SupportResource] = [
        emergency112(
            id: "da-112",
            name: "Nødnummer 112",
            detail: "Ved umiddelbar fare, ring 112 — nødnummeret i hele Europa."
        ),
        findHelpline(
            id: "da-findahelpline",
            name: "Find en hjælpelinje",
            detail: "Find en hjælpelinje i dit land på findahelpline.com.",
            region: "DK"
        ),
        iasp(
            id: "da-iasp",
            name: "Et krisecenter nær dig",
            detail: "IASP har en oversigt på iasp.info/resources/Crisis_Centres."
        ),
    ]

    static let russian: [SupportResource] = [
        emergency112(
            id: "ru-112",
            name: "Экстренный номер 112",
            detail: "При непосредственной опасности звони 112 — единый номер экстренных служб."
        ),
        findHelpline(
            id: "ru-findahelpline",
            name: "Найти линию поддержки",
            detail: "Найди линию поддержки в своей стране на findahelpline.com.",
            region: "RU"
        ),
        iasp(
            id: "ru-iasp",
            name: "Кризисный центр рядом",
            detail: "IASP ведёт каталог на iasp.info/resources/Crisis_Centres."
        ),
    ]
}
