import Testing
@testable import BookApp

/// Phase 2 memory-intelligence services: teach-back grading and card
/// generation. Tests cover the pure, deterministic bits (score->grade mapping,
/// JSON parsing with and without code fences, cloze masking) and the prompt
/// contracts. The LLM-backed `grade`/`makeCloze`/`reformulate` calls are not
/// exercised here since they require a live provider.
@MainActor
struct MemoryIntelligenceTests {

    // MARK: - score -> grade boundaries

    @Test
    func scoreToGradeBoundaries() {
        #expect(TeachBackGrader.grade(forScore: 0) == .again)
        #expect(TeachBackGrader.grade(forScore: 39) == .again)
        #expect(TeachBackGrader.grade(forScore: 40) == .hard)
        #expect(TeachBackGrader.grade(forScore: 69) == .hard)
        #expect(TeachBackGrader.grade(forScore: 70) == .good)
        #expect(TeachBackGrader.grade(forScore: 89) == .good)
        #expect(TeachBackGrader.grade(forScore: 90) == .easy)
        #expect(TeachBackGrader.grade(forScore: 100) == .easy)
    }

    // MARK: - parseGrade

    @Test
    func parseGradeHandlesCleanJSON() {
        let json = """
        {"score": 75, "missedPoints": ["the timing nuance"], "feedback": "Solid, one gap."}
        """
        let result = TeachBackGrader.parseGrade(json)
        #expect(result?.score == 75)
        #expect(result?.missedPoints == ["the timing nuance"])
        #expect(result?.feedback == "Solid, one gap.")
        #expect(result?.grade == .good)
    }

    @Test
    func parseGradeHandlesFencedJSON() {
        let json = """
        ```json
        {"score": 95, "missedPoints": [], "feedback": "Complete."}
        ```
        """
        let result = TeachBackGrader.parseGrade(json)
        #expect(result?.score == 95)
        #expect(result?.missedPoints == [])
        #expect(result?.grade == .easy)
    }

    @Test
    func parseGradeReturnsNilOnGarbage() {
        #expect(TeachBackGrader.parseGrade("not json at all") == nil)
        #expect(TeachBackGrader.parseGrade("") == nil)
    }

    @Test
    func parseGradeClampsScore() {
        let high = TeachBackGrader.parseGrade(#"{"score": 140, "missedPoints": [], "feedback": ""}"#)
        #expect(high?.score == 100)
        #expect(high?.grade == .easy)
        let low = TeachBackGrader.parseGrade(#"{"score": -20, "missedPoints": [], "feedback": ""}"#)
        #expect(low?.score == 0)
        #expect(low?.grade == .again)
    }

    // MARK: - parseCloze

    @Test
    func parseClozeHandlesCleanJSON() {
        let json = """
        {"front": "Cruelty in one decisive stroke is forgiven faster than cruelty drawn out.", \
        "back": "one decisive stroke", "clozeMask": "one decisive stroke"}
        """
        let cloze = CardGenerator.parseCloze(json)
        #expect(cloze?.front.contains("Cruelty") == true)
        #expect(cloze?.back == "one decisive stroke")
        #expect(cloze?.clozeMask == "one decisive stroke")
    }

    @Test
    func parseClozeHandlesFencedJSON() {
        let json = """
        ```json
        {"front": "What is the riskier path?", "back": "drawn-out cruelty", "clozeMask": ""}
        ```
        """
        let cloze = CardGenerator.parseCloze(json)
        #expect(cloze?.front == "What is the riskier path?")
        #expect(cloze?.back == "drawn-out cruelty")
        // clozeMask is "" and back is not a substring of front -> stays "" (Q&A).
        #expect(cloze?.clozeMask == "")
    }

    @Test
    func parseClozeReturnsNilOnGarbage() {
        #expect(CardGenerator.parseCloze("garbage, not json") == nil)
        #expect(CardGenerator.parseCloze(#"{"front": "", "back": "x"}"#) == nil)
        #expect(CardGenerator.parseCloze("") == nil)
    }

    @Test
    func parseClozeRecomputesMaskWhenModelMaskIsWrong() {
        // Model claims a mask that isn't in `front`; we fall back to `back` if it
        // is a substring of `front`.
        let json = """
        {"front": "Trust compounds slowly and breaks fast.", \
        "back": "compounds slowly", "clozeMask": "not present here"}
        """
        let cloze = CardGenerator.parseCloze(json)
        #expect(cloze?.clozeMask == "compounds slowly")
    }

    // MARK: - mask(for:in:)

    @Test
    func maskFindsSpanWhenPresent() {
        let front = "Trust compounds slowly and breaks fast."
        #expect(CardGenerator.mask(for: "compounds slowly", in: front) == "compounds slowly")
    }

    @Test
    func maskReturnsEmptyWhenAbsent() {
        let front = "Trust compounds slowly and breaks fast."
        #expect(CardGenerator.mask(for: "erodes overnight", in: front) == "")
        #expect(CardGenerator.mask(for: "", in: front) == "")
    }

    // MARK: - prompt contracts

    @Test
    func clozeFromIdeaPromptHasRequiredKeys() {
        let (system, user) = PromptTemplates.clozeFromIdea("Trust compounds slowly.")
        #expect(system.contains("\"front\""))
        #expect(system.contains("\"back\""))
        #expect(system.contains("\"clozeMask\""))
        #expect(system.contains("JSON only"))
        #expect(user.contains("Trust compounds slowly."))
    }

    @Test
    func reformulateCardPromptHasRequiredKeys() {
        let (system, user) = PromptTemplates.reformulateCard(
            idea: "Trust compounds slowly.",
            failedAttempts: ["trust is fast", "trust is money"]
        )
        #expect(system.contains("\"front\""))
        #expect(system.contains("\"back\""))
        #expect(system.contains("\"clozeMask\""))
        #expect(system.contains("JSON only"))
        #expect(user.contains("Trust compounds slowly."))
        #expect(user.contains("trust is fast"))
    }
}
