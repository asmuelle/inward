@testable import CaptureKit
import Foundation
import JournalStore
import Testing

private func association(_ kind: EntityKind, _ name: String, mentions: Int) -> EntityAssociation {
    EntityAssociation(
        entity: JournalEntity(kind: kind, name: name),
        entryIDs: (0 ..< mentions).map { _ in UUID() }
    )
}

@Suite("PersonalLexicon — the journal teaches the microphone its names")
struct PersonalLexiconTests {
    @Test("people and places rank by mention count; other kinds are excluded")
    func ranksPeopleAndPlaces() {
        // Arrange
        let associations = [
            association(.place, "Wilhelmstraße", mentions: 2),
            association(.person, "Saoirse", mentions: 5),
            association(.topic, "the move", mentions: 9),
            association(.object, "piano", mentions: 7),
        ]

        // Act
        let terms = PersonalLexicon.terms(from: associations, tags: [])

        // Assert — topics and objects never bias the microphone
        #expect(terms == ["Saoirse", "Wilhelmstraße"])
    }

    @Test("tag names follow the ranked entities")
    func tagsAppendAfterEntities() {
        let associations = [association(.person, "Saoirse", mentions: 3)]
        let tags = [Tag(name: "therapy"), Tag(name: "garden")]

        let terms = PersonalLexicon.terms(from: associations, tags: tags)

        #expect(terms == ["Saoirse", "therapy", "garden"])
    }

    @Test("duplicates collapse case-insensitively, keeping the first casing")
    func dedupesCaseInsensitively() {
        let associations = [
            association(.person, "Saoirse", mentions: 5),
            association(.place, "saoirse", mentions: 1),
        ]
        let tags = [Tag(name: "SAOIRSE")]

        let terms = PersonalLexicon.terms(from: associations, tags: tags)

        #expect(terms == ["Saoirse"])
    }

    @Test("single-character noise and unmentioned entities are dropped")
    func dropsNoise() {
        let associations = [
            association(.person, "A", mentions: 4),
            EntityAssociation(entity: JournalEntity(kind: .person, name: "Ghost"), entryIDs: []),
        ]

        #expect(PersonalLexicon.terms(from: associations, tags: []).isEmpty)
    }

    @Test("the list caps at maxTerms")
    func capsAtMaxTerms() {
        let associations = (0 ..< 150).map { association(.person, "Name\($0)", mentions: 150 - $0) }

        let terms = PersonalLexicon.terms(from: associations, tags: [])

        #expect(terms.count == PersonalLexicon.maxTerms)
        #expect(terms.first == "Name0") // most mentioned stays first
    }

    @Test("mention-count ties break alphabetically for stability")
    func tiesBreakByName() {
        let associations = [
            association(.person, "Zara", mentions: 2),
            association(.person, "Ben", mentions: 2),
        ]

        #expect(PersonalLexicon.terms(from: associations, tags: []) == ["Ben", "Zara"])
    }
}
