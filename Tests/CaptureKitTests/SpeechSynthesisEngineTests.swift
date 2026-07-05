@testable import CaptureKit
import Foundation
import Testing

@Suite("SpeechSynthesisEngine — spoken-summary output")
struct SpeechSynthesisEngineTests {
    @Test("mock records non-empty utterances and their locales in order")
    func mockRecordsUtterances() async {
        // Arrange
        let engine = MockSpeechSynthesisEngine()

        // Act
        await engine.speak("Here's what I heard.", locale: "en_US")
        await engine.speak("Want to keep it?", locale: "de_DE")

        // Assert
        #expect(await engine.spokenUtterances == ["Here's what I heard.", "Want to keep it?"])
        #expect(await engine.spokenLocales == ["en_US", "de_DE"])
    }

    @Test("mock skips empty and whitespace-only text, mirroring the real engine")
    func mockSkipsEmptyText() async {
        // Arrange
        let engine = MockSpeechSynthesisEngine()

        // Act
        await engine.speak("", locale: "en_US")
        await engine.speak("   \n  ", locale: "en_US")
        await engine.speak("real words", locale: "en_US")

        // Assert
        #expect(await engine.spokenUtterances == ["real words"])
    }

    @Test("mock trims surrounding whitespace before recording")
    func mockTrimsWhitespace() async {
        // Arrange
        let engine = MockSpeechSynthesisEngine()

        // Act
        await engine.speak("  padded summary  ", locale: "en_US")

        // Assert
        #expect(await engine.spokenUtterances == ["padded summary"])
    }

    @Test("mock reports the availability it was configured with")
    func mockAvailability() async {
        // Arrange
        let available = MockSpeechSynthesisEngine()
        let unavailable = MockSpeechSynthesisEngine(availability: .unavailable(reason: "no voices"))

        // Act & Assert
        #expect(await available.availability().isAvailable)
        #expect(await unavailable.availability().isAvailable == false)
    }

    @Test("stop is recorded for test inspection")
    func mockStop() async {
        // Arrange
        let engine = MockSpeechSynthesisEngine()

        // Act
        await engine.stop()

        // Assert
        #expect(await engine.didStop)
    }
}
