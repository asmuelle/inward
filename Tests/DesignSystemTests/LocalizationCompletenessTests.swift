@testable import DesignSystem
import Testing

@Suite("Localization — every language is complete and consistent")
struct LocalizationCompletenessTests {
    @Test("every language table covers exactly the same keys")
    func tablesShareKeys() {
        let reference = Set(Translations.de.keys)
        #expect(reference.count >= 80, "the reference table should hold the full surface")

        for (code, table) in Localized.tables {
            let missing = reference.subtracting(table.keys)
            let extra = Set(table.keys).subtracting(reference)
            #expect(missing.isEmpty, "\(code) is missing: \(missing.sorted())")
            #expect(extra.isEmpty, "\(code) has unexpected: \(extra.sorted())")
        }
    }

    @Test("the plural import line keeps its %d placeholder in every language")
    func pluralPlaceholderPreserved() {
        for (code, table) in Localized.tables {
            #expect(table["importDoneMany"]?.contains("%d") == true, "\(code) lost %d")
        }
    }

    @Test("no translation is blank")
    func noBlankValues() {
        for (code, table) in Localized.tables {
            for (key, value) in table {
                #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "\(code).\(key) is blank")
            }
        }
    }
}
