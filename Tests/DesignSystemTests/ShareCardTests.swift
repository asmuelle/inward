@testable import DesignSystem
import Testing

#if canImport(SwiftUI)
    import SwiftUI

    @Suite("Share cards — restraint, and a picture that actually renders")
    struct ShareCardTests {
        @Test("the themes card keeps at most five words")
        func themesAreCapped() {
            // Arrange
            let themes = ["sleep", "the move", "patience", "money", "my father", "running", "sunday"]

            // Act
            let displayed = ThemesShareCard.displayed(themes)

            // Assert
            #expect(displayed.count == ThemesShareCard.maxThemes)
            #expect(displayed == Array(themes.prefix(5)))
        }

        @Test("blank and padded words never reach the card")
        func blanksAreDropped() {
            // Arrange
            let themes = ["  sleep ", "   ", "", "\n", "patience"]

            // Act
            let displayed = ThemesShareCard.displayed(themes)

            // Assert
            #expect(displayed == ["sleep", "patience"])
        }

        @Test("fewer words than the cap are all kept, in order")
        func shortListSurvivesIntact() {
            #expect(ThemesShareCard.displayed(["rain", "quiet"]) == ["rain", "quiet"])
        }

        @Test("the card geometry stays the 4:5 the layout is built around")
        func cardGeometryIsPortrait() {
            let size = Lamplight.ShareCard.size
            #expect(size.width / size.height == 0.8)
            // Rasterization itself is asserted in the simulator-hosted app tests
            // (ShareCardRenderTests) — SwiftUI won't render headlessly here.
        }
    }
#endif
