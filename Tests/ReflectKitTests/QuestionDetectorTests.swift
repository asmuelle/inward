@testable import ReflectKit
import Testing

@Suite("QuestionDetector — the ask affordance appears only for questions")
struct QuestionDetectorTests {
    @Test("a trailing question mark marks a question", arguments: [
        "when did I last sleep well?",
        "garden mornings?",
        "¿Cuándo dormí bien?",
        "いつ？ よく寝た？",
    ])
    func trailingMark(_ text: String) {
        #expect(QuestionDetector.isQuestion(text))
    }

    @Test("a question opener works without the mark", arguments: [
        "when did I last feel rested",
        "How often do I mention the garden",
        "Wann habe ich zuletzt gut geschlafen",
        "pourquoi je parle du jardin",
        "когда я писал о саде",
    ])
    func openerWithoutMark(_ text: String) {
        #expect(QuestionDetector.isQuestion(text))
    }

    @Test("plain word search is not a question", arguments: [
        "garden",
        "garden mornings",
        "deadline pressure stacked",
        "",
        "   ",
    ])
    func plainSearch(_ text: String) {
        #expect(!QuestionDetector.isQuestion(text))
    }

    @Test("a lone question word has nothing to retrieve on")
    func loneOpener() {
        #expect(!QuestionDetector.isQuestion("why?"))
        #expect(!QuestionDetector.isQuestion("when"))
    }
}
