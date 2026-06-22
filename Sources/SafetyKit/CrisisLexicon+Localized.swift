import Foundation

/// Additive localized crisis phrases. These EXTEND the English lexicon — they
/// never replace it, so an English phrase still matches even under a localized
/// build (a German user may write in English, and vice versa). Phrases are matched
/// whole-word on diacritic-folded, lowercased text (see TextNormalizer), so natural
/// spelling is fine here. Machine-drafted from the English set; flagged for native
/// and professional review before release — like the English lexicon, recall
/// matters more than elegance, so err toward including a phrasing.
extension CrisisLexicon {
    /// Additive localized phrase tables, keyed by ISO 639 language code.
    static let localized: [String: [CrisisCategory: [String]]] = [
        "de": german,
        "fr": french,
        "it": italian,
        "pt": portuguese,
        "es": spanish,
        "nb": norwegian,
        "sv": swedish,
        "da": danish,
        "ru": russian,
    ]

    /// The English lexicon plus any additive phrases for `languageCode`. Unknown
    /// codes and English itself return English unchanged. Per category the two
    /// sets are unioned, so localized phrasings widen recall without ever dropping
    /// an English match.
    public static func merged(forLanguage languageCode: String?) -> [CrisisCategory: [String]] {
        guard let languageCode, languageCode != "en", let extra = localized[languageCode] else {
            return english
        }
        return english.merging(extra) { englishPhrases, localizedPhrases in
            englishPhrases + localizedPhrases.filter { !englishPhrases.contains($0) }
        }
    }

    static let german: [CrisisCategory: [String]] = [
        .selfHarm: [
            "mich umbringen", "umbringen", "mein leben beenden", "selbstmord", "suizid",
            "suizidgedanken", "mich verletzen", "mir etwas antun", "nicht mehr leben",
            "will nicht mehr leben", "will sterben", "lieber tot", "besser tot",
            "wäre besser tot", "keinen grund mehr zu leben",
        ],
        .harmFromOthers: [
            "er schlägt mich", "sie schlägt mich", "werde geschlagen", "werde misshandelt",
            "häusliche gewalt", "angst vor ihm", "angst nach hause zu gehen",
        ],
        .overdose: ["überdosis", "zu viele tabletten", "zu viele pillen genommen"],
    ]

    static let french: [CrisisCategory: [String]] = [
        .selfHarm: [
            "me tuer", "mettre fin à mes jours", "mettre fin à ma vie", "suicide", "suicidaire",
            "me faire du mal", "envie de mourir", "je veux mourir", "ne plus vouloir vivre",
            "mieux mort", "mieux sans moi", "plus de raison de vivre",
        ],
        .harmFromOthers: [
            "il me frappe", "elle me frappe", "ils me frappent", "je suis maltraité",
            "violence conjugale", "violence domestique", "peur de rentrer",
        ],
        .overdose: ["overdose", "surdose", "trop de cachets", "trop de comprimés"],
    ]

    static let italian: [CrisisCategory: [String]] = [
        .selfHarm: [
            "uccidermi", "farla finita", "togliermi la vita", "suicidio", "suicida",
            "farmi del male", "voglio morire", "non voglio più vivere", "meglio morto",
            "meglio se non ci fossi", "nessun motivo per vivere",
        ],
        .harmFromOthers: [
            "mi picchia", "mi picchiano", "vengo picchiato", "vengo maltrattato",
            "violenza domestica", "paura di tornare a casa",
        ],
        .overdose: ["overdose", "troppe pastiglie", "troppe pillole"],
    ]

    static let portuguese: [CrisisCategory: [String]] = [
        .selfHarm: [
            "me matar", "acabar com a minha vida", "pôr fim à vida", "suicídio", "suicida",
            "me machucar", "me ferir", "quero morrer", "não quero mais viver",
            "melhor morto", "melhor sem mim", "sem motivo para viver",
        ],
        .harmFromOthers: [
            "ele me bate", "ela me bate", "estou sendo agredido", "estou a ser agredido",
            "violência doméstica", "medo de voltar para casa",
        ],
        .overdose: ["overdose", "comprimidos a mais", "muitos comprimidos"],
    ]

    static let spanish: [CrisisCategory: [String]] = [
        .selfHarm: [
            "matarme", "acabar con mi vida", "quitarme la vida", "suicidio", "suicidarme",
            "hacerme daño", "quiero morir", "ya no quiero vivir", "mejor muerto",
            "mejor sin mí", "no tengo razones para vivir",
        ],
        .harmFromOthers: [
            "me pega", "me pegan", "me maltratan", "estoy siendo maltratado",
            "violencia doméstica", "miedo de volver a casa",
        ],
        .overdose: ["sobredosis", "demasiadas pastillas", "demasiadas pildoras"],
    ]

    static let norwegian: [CrisisCategory: [String]] = [
        .selfHarm: [
            "ta livet mitt", "ta mitt eget liv", "avslutte livet", "selvmord", "selvmordstanker",
            "skade meg selv", "vil dø", "vil jeg dø", "vil ikke leve mer", "bedre død", "bedre uten meg",
            "ingen grunn til å leve",
        ],
        .harmFromOthers: [
            "han slår meg", "hun slår meg", "blir slått", "blir mishandlet",
            "vold i hjemmet", "redd for å dra hjem",
        ],
        .overdose: ["overdose", "for mange piller", "for mange tabletter"],
    ]

    static let swedish: [CrisisCategory: [String]] = [
        .selfHarm: [
            "ta mitt liv", "ta mitt eget liv", "avsluta mitt liv", "självmord", "självmordstankar",
            "skada mig själv", "vill dö", "vill jag dö", "vill inte leva längre", "bättre död", "bättre utan mig",
            "ingen anledning att leva",
        ],
        .harmFromOthers: [
            "han slår mig", "hon slår mig", "blir slagen", "blir misshandlad",
            "våld i hemmet", "rädd för att gå hem",
        ],
        .overdose: ["överdos", "för många tabletter", "för många piller"],
    ]

    static let danish: [CrisisCategory: [String]] = [
        .selfHarm: [
            "tage mit eget liv", "ende mit liv", "slå mig selv ihjel", "selvmord", "selvmordstanker",
            "skade mig selv", "vil dø", "vil jeg dø", "vil ikke leve mere", "bedre død", "bedre uden mig",
            "ingen grund til at leve",
        ],
        .harmFromOthers: [
            "han slår mig", "hun slår mig", "bliver slået", "bliver mishandlet",
            "vold i hjemmet", "bange for at tage hjem",
        ],
        .overdose: ["overdosis", "for mange piller", "for mange tabletter"],
    ]

    static let russian: [CrisisCategory: [String]] = [
        .selfHarm: [
            "убить себя", "покончить с собой", "покончить с жизнью", "суицид", "самоубийство",
            "причинить себе вред", "хочу умереть", "не хочу больше жить", "лучше умереть",
            "лучше без меня", "нет смысла жить",
        ],
        .harmFromOthers: [
            "он меня бьёт", "она меня бьёт", "меня бьют", "надо мной издеваются",
            "домашнее насилие", "боюсь идти домой",
        ],
        .overdose: ["передозировка", "слишком много таблеток", "выпил много таблеток"],
    ]
}
