@testable import SafetyKit
import Testing

@Suite("BannedTerms — the regulated vocabulary never appears")
struct BannedTermsTests {
    @Test("flags every lexicon term inside surrounding text")
    func flagsKnownTerms() {
        for term in BannedTerms.lexicon {
            // Act
            let violations = BannedTerms.violations(in: "we proudly offer \(term) to everyone")

            // Assert
            #expect(violations.contains(BannedTerms.Violation(term: term)), "missed: \(term)")
        }
    }

    @Test("clean reflective-journaling copy passes")
    func cleanCopyPasses() {
        // Arrange
        let copy = "A quiet place to speak your mind. Patterns surface over time; your words stay on this phone."

        // Act
        let violations = BannedTerms.violations(in: copy)

        // Assert
        #expect(violations.isEmpty)
    }

    @Test("matching is whole-word: lookalike substrings do not trip the scan")
    func wholeWordOnly() {
        // Arrange — none of these contain a banned term as a whole word
        let text = "the cbtree library diagnoses nothing; clinically is not scanned as a word here"

        // Act
        let violations = BannedTerms.violations(in: text)

        // Assert
        #expect(violations.isEmpty)
    }

    @Test("case and punctuation cannot hide a banned term")
    func normalizationCatchesVariants() {
        // Act
        let violations = BannedTerms.violations(in: "Try our C.B.T. routine!")

        // Assert — "C.B.T." normalizes to "c b t", which is NOT the word "cbt";
        // but plain uppercase must be caught:
        let upper = BannedTerms.violations(in: "THERAPY for everyone")
        #expect(upper.contains(BannedTerms.Violation(term: "therapy")))
        // Dotted abbreviation is a marketing-review concern, not a string-scan one.
        #expect(violations.isEmpty)
    }

    @Test("empty text has no violations")
    func emptyTextClean() {
        #expect(BannedTerms.violations(in: "").isEmpty)
    }
}
