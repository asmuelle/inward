import Foundation
@testable import SafetyKit
import Testing

private struct GateFixtureFile: Codable {
    struct Case: Codable {
        let name: String
        let text: String
        let expectMatch: Bool
        let categories: [String]
    }

    let cases: [Case]
}

private func loadFixtures() throws -> [GateFixtureFile.Case] {
    let url = try #require(Bundle.module.url(forResource: "Fixtures/crisis_fixtures", withExtension: "json"))
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(GateFixtureFile.self, from: data).cases
}

@Suite("CrisisGate — deterministic keyword gate")
struct CrisisGateTests {
    @Test("seeded fixtures match exactly as recorded")
    func fixturesBehaveAsSeeded() throws {
        // Arrange
        let gate = CrisisGate()
        let cases = try loadFixtures()
        #expect(!cases.isEmpty)

        for fixture in cases {
            // Act
            let decision = gate.evaluate(fixture.text)

            // Assert
            #expect(decision.isMatched == fixture.expectMatch, "fixture failed: \(fixture.name)")
            if case let .matched(matches, resources) = decision {
                let matchedCategories = Set(matches.map(\.category.rawValue))
                #expect(matchedCategories.isSuperset(of: fixture.categories), "fixture failed: \(fixture.name)")
                #expect(!resources.isEmpty, "a match must always carry resources: \(fixture.name)")
            }
        }
    }

    @Test("matched decision always surfaces the bundled static resources")
    func matchSurfacesStaticResources() {
        // Arrange
        let gate = CrisisGate()

        // Act
        let decision = gate.evaluate("I want to die")

        // Assert
        guard case let .matched(_, resources) = decision else {
            Issue.record("expected a match")
            return
        }
        #expect(resources == SupportResource.bundled)
        #expect(resources.count >= 3)
    }

    @Test("gate decision is deterministic across repeated evaluation")
    func gateIsDeterministic() {
        // Arrange
        let gate = CrisisGate()
        let text = "I keep wondering if everyone would be better off dead without me around"

        // Act
        let first = gate.evaluate(text)
        let second = gate.evaluate(text)

        // Assert
        #expect(first == second)
    }

    @Test("diacritics and punctuation cannot dodge the gate")
    func normalizationDefeatsObfuscation() {
        // Arrange
        let gate = CrisisGate()

        // Act
        let decision = gate.evaluate("I want to (kill—myself) tonight…")

        // Assert
        #expect(decision.isMatched)
    }

    @Test("clear text yields clear")
    func clearTextIsClear() {
        // Arrange
        let gate = CrisisGate()

        // Act
        let decision = gate.evaluate("Long walk, cold air, felt a little lighter today.")

        // Assert
        #expect(decision == .clear)
    }

    @Test("bundled resource directory is never empty")
    func bundledResourcesExist() {
        #expect(!SupportResource.bundled.isEmpty)
        #expect(SupportResource.bundled.allSatisfy { !$0.name.isEmpty && !$0.detail.isEmpty })
    }
}
