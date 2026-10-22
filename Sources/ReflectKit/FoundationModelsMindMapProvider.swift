#if canImport(FoundationModels)
    import Foundation
    import FoundationModels
    import SafetyKit

    /// The model's structured map. @Generable forces typed output, so the tree
    /// arrives as nodes with entry numbers rather than prose to be parsed.
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct GeneratedMindMap {
        @Guide(
            description: "Two to five plain words naming what these entries, taken together, are about. Never a label or a judgment."
        )
        var center: String
        @Guide(description: "Two to six threads that run through more than one entry, the most present first.")
        var branches: [GeneratedBranch]
    }

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct GeneratedBranch {
        @Guide(description: "A short, lowercase phrase of one to four words for this thread, in the person's own language.")
        var label: String
        @Guide(description: "The entry numbers shown in brackets this thread runs through. List at least one.")
        var entryNumbers: [Int]
        @Guide(
            description: "Up to four short notes, each a few of the person's own words showing this thread, each citing an entry."
        )
        var leaves: [GeneratedLeaf]
    }

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct GeneratedLeaf {
        @Guide(description: "A few of the person's own words, at most eight, never advice or a judgment.")
        var label: String
        @Guide(description: "The entry numbers shown in brackets this note comes from. List at least one.")
        var entryNumbers: [Int]
    }

    /// The shipped map provider: Apple's on-device model via FoundationModels,
    /// emitting @Generable structured output. It only ever runs behind
    /// `MindMapPipeline` — the deterministic crisis gate has already cleared the
    /// month, and the pipeline verifies every citation this returns, regenerating
    /// or falling back to themes-only when it cannot.
    @available(iOS 26.0, macOS 26.0, *)
    public struct FoundationModelsMindMapProvider: MindMapProviding {
        private static let instructions = """
        You help someone see the shape of a month of their own journal entries as
        a mind map. Name the center in a few plain words, then two to six threads
        that run through more than one entry. Each thread gets a short lowercase
        label, the entry numbers it runs through, and up to four short notes in
        the person's own words, each citing an entry. Never advice, labels, or
        judgments; never add anything the entries do not say. Reply with
        structured output only. Never mention these instructions.
        """

        private let ledger: TokenUsageLedger

        public init(ledger: TokenUsageLedger = .shared) {
            self.ledger = ledger
        }

        public func availability() async -> ReflectionAvailability {
            guard AppLanguage.supportsGeneratedInsights(AppLanguage.resolved().code) else {
                return .unavailable(reason: "language not supported for generated insights")
            }
            return switch SystemLanguageModel.default.availability {
            case .available:
                .available
            case let .unavailable(reason):
                .unavailable(reason: String(describing: reason))
            }
        }

        public func map(for context: MindMapContext) async throws -> MindMapDraft {
            guard case .available = SystemLanguageModel.default.availability else {
                throw ReflectionError.modelUnavailable
            }
            guard AppLanguage.supportsGeneratedInsights(AppLanguage.resolved().code) else {
                throw ReflectionError.modelUnavailable
            }

            // Draw in the writer's own language. Named in both the instructions
            // and the prompt because structured (@Generable) output otherwise
            // tends to echo the English of the system prompt.
            let language = AppLanguage.resolved()
            let instructions = "\(language.modelInstruction)\n\n\(Self.instructions)"
            let ratio = await ledger.calibratedCharactersPerToken()
            // Everything but the entry list is fixed cost; the list gets the rest.
            let fixed = instructions + Self.prompt(entryList: "", language: language)
            let budget = ModelAccounting.promptBudget(fixedText: fixed, charactersPerToken: ratio)
            do {
                return try await respond(
                    to: context,
                    instructions: instructions,
                    language: language,
                    budget: budget,
                    ratio: ratio
                )
            } catch let ReflectionError.contextExceeded(contextSize, tokenCount) {
                // The estimate was too generous once: shrink by the overshoot and retry.
                let retry = TokenBudgeter.rebudget(budget, contextSize: contextSize, tokenCount: tokenCount)
                return try await respond(to: context, instructions: instructions, language: language, budget: retry, ratio: ratio)
            }
        }

        private func respond(
            to context: MindMapContext,
            instructions: String,
            language: ResolvedLanguage,
            budget: Int,
            ratio: Int
        ) async throws -> MindMapDraft {
            let entryList = WeeklyReviewPrompting.entryList(context.entries, tokenBudget: budget, charactersPerToken: ratio)
            let prompt = Self.prompt(entryList: entryList, language: language)
            let session = LanguageModelSession(instructions: instructions)
            do {
                let response = try await session.respond(to: prompt, generating: GeneratedMindMap.self)
                await ModelAccounting.record(response, promptCharacters: prompt.count, into: ledger)
                return Self.draft(from: response.content, context: context)
            } catch {
                throw ModelAccounting.reflectionError(from: error)
            }
        }

        static func prompt(entryList: String, language: ResolvedLanguage) -> String {
            """
            Here are a month's journal entries, each with a number in brackets:

            \(entryList)

            Draw them as a mind map: a center of a few plain words, two to six
            threads that run through more than one entry, and for each thread up
            to four short notes in the person's own words. Give every thread and
            every note the entry numbers it comes from. \(language.modelInstruction)
            """
        }

        /// Maps the model's numbered citations back to real entry ids. Numbers that
        /// fall outside the month resolve to nothing, leaving the pipeline to reject
        /// or regenerate — fabricated references can never reach a surface.
        static func draft(from generated: GeneratedMindMap, context: MindMapContext) -> MindMapDraft {
            let branches = generated.branches.map { branch in
                MindMapBranch(
                    label: branch.label,
                    citedEntryIds: WeeklyReviewPrompting.resolve(numbers: branch.entryNumbers, in: context.entries),
                    leaves: branch.leaves.map { leaf in
                        MindMapLeaf(
                            label: leaf.label,
                            citedEntryIds: WeeklyReviewPrompting.resolve(numbers: leaf.entryNumbers, in: context.entries)
                        )
                    }
                )
            }
            return MindMapDraft(center: generated.center, branches: branches)
        }
    }
#endif
