@testable import SafetyKit
import Testing

@Suite("ModelPromptBudget — every model input stays inside the on-device window")
struct ModelPromptBudgetTests {
    @Test("the total and input budgets reserve schema and output room")
    func publishedLimit() {
        #expect(ModelPromptBudget.contextWindow == 4096)
        #expect(ModelPromptBudget.inputLimit == 2800)
    }

    @Test("large journal text is truncated on a word boundary")
    func fittingPrefix() {
        let source = Array(repeating: "private journal sentence", count: 2000).joined(separator: " ")

        let result = ModelPromptBudget.fittingPrefix(source, maxTokens: 256)

        #expect(ModelPromptBudget.estimateTokens(result) <= 256)
        #expect(!result.isEmpty)
        #expect(!result.hasSuffix("private jour"))
    }
}
