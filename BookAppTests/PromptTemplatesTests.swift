import Testing
@testable import BookApp

struct PromptTemplatesTests {

    @Test
    func compressionDirectiveMentionsRatio() {
        let (system, _) = PromptTemplates.transformChunk(
            kind: .compressed,
            targetRatio: 0.25,
            styleReference: "",
            omittedThemes: [],
            chunkIndex: 0,
            chunkCount: 4
        )
        #expect(system.contains("25%"))
        #expect(system.contains("Compress"))
    }

    @Test
    func styleTransferReferencesAuthor() {
        let (system, _) = PromptTemplates.transformChunk(
            kind: .styled,
            targetRatio: 1.0,
            styleReference: "Malcolm Gladwell",
            omittedThemes: [],
            chunkIndex: 0,
            chunkCount: 1
        )
        #expect(system.contains("Malcolm Gladwell"))
    }

    @Test
    func themeOmissionListsThemes() {
        let (system, _) = PromptTemplates.transformChunk(
            kind: .themeOmitted,
            targetRatio: 1.0,
            styleReference: "",
            omittedThemes: ["religion", "violence"],
            chunkIndex: 0,
            chunkCount: 1
        )
        #expect(system.contains("religion"))
        #expect(system.contains("violence"))
    }

    /// The v10 prompt rewrite added explicit no-meta-commentary and
    /// no-fence rules. Both must survive — without them the model
    /// regularly prepends "Here is the rewritten passage:" which then
    /// shows up in the user's reader.
    @Test
    func transformPromptForbidsMetaCommentary() {
        let (system, _) = PromptTemplates.transformChunk(
            kind: .compressed,
            targetRatio: 0.5,
            styleReference: "",
            omittedThemes: [],
            chunkIndex: 0,
            chunkCount: 1
        )
        #expect(system.contains("ONLY the rewritten prose"))
        #expect(system.contains("no markdown code fences"))
    }

    /// Expansion must explicitly forbid hallucination — that's the
    /// single biggest failure mode for "expand a 5-page chapter to 25".
    @Test
    func expansionForbidsInventedFacts() {
        let (system, _) = PromptTemplates.transformChunk(
            kind: .expanded,
            targetRatio: 2.0,
            styleReference: "",
            omittedThemes: [],
            chunkIndex: 0,
            chunkCount: 1
        )
        #expect(system.contains("Do NOT introduce new claims"))
    }

    @Test
    func categoryTaggingDemandsJSONOnly() {
        let (system, _) = PromptTemplates.categoryTagging(
            title: "Sapiens",
            author: "Yuval Noah Harari",
            sample: "100,000 years ago, at least six human species inhabited the earth."
        )
        #expect(system.contains("JSON only"))
        #expect(system.contains("\"categories\""))
        #expect(system.contains("\"themes\""))
    }

    @Test
    func chatWithBookKeepsAnswersGrounded() {
        let (system, _) = PromptTemplates.chatWithBook(question: "What's the main argument?")
        #expect(system.contains("strictly from its content"))
        #expect(system.contains("doesn't address that"))
    }

    @Test
    func seamRewriteOutputsJSON() {
        let (system, _) = PromptTemplates.seamRewrite()
        #expect(system.contains("\"left\""))
        #expect(system.contains("\"right\""))
        #expect(system.contains("JSON only"))
    }

    /// Teach-back grading must score the idea, not the writing — penalising
    /// phrasing would defeat the whole point of the Feynman/teach-back card.
    @Test
    func teachBackGradingScoresIdeaNotStyle() {
        let (system, user) = PromptTemplates.teachBackGrading(
            idea: "Cruelty in one decisive stroke is forgiven faster than cruelty drawn out.",
            explanation: "Get the harsh stuff over with quickly so people move on."
        )
        #expect(system.contains("\"score\""))
        #expect(system.contains("\"missedPoints\""))
        #expect(system.contains("Never penalise"))
        #expect(system.contains("JSON only"))
        #expect(user.contains("Cruelty in one decisive stroke"))
        #expect(user.contains("Get the harsh stuff over with quickly"))
    }
}
