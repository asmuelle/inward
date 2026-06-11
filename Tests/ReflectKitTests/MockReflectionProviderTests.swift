@testable import ReflectKit
import Testing

@Suite("MockReflectionProvider — deterministic by construction")
struct MockReflectionProviderTests {
    @Test("same entry text produces the identical reflection every time")
    func deterministicAcrossCalls() async throws {
        // Arrange
        let provider = MockReflectionProvider()
        let text = "Walked past the old apartment today and didn't slow down."

        // Act
        let first = try await provider.reflection(for: text)
        let second = try await provider.reflection(for: text)

        // Assert
        #expect(first == second)
    }

    @Test("output always fits the pipeline schema")
    func outputFitsSchema() async throws {
        // Arrange
        let provider = MockReflectionProvider()
        let samples = [
            "Short.",
            "A much longer entry about the week, the deadlines, the apologies I owe and the ones I'm owed.",
            "weekend trip mountains rain cabin board games laughter",
        ]

        for text in samples {
            // Act
            let prompt = try await provider.reflection(for: text)

            // Assert
            #expect(ReflectionPipeline.validate(prompt), "invalid output for: \(text)")
        }
    }

    @Test("stable hash is stable")
    func stableHashIsStable() {
        #expect(MockReflectionProvider.stableHash("inward") == MockReflectionProvider.stableHash("inward"))
        #expect(MockReflectionProvider.stableHash("a") != MockReflectionProvider.stableHash("b"))
    }

    @Test("themes are at most three distinct longer words")
    func themesBounded() {
        // Act
        let themes = MockReflectionProvider.themes(from: "river river crossing crossing morning frost gravel path")

        // Assert
        #expect(themes.count <= 3)
        #expect(Set(themes).count == themes.count)
    }
}
