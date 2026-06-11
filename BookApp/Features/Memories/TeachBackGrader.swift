import Foundation

/// Grades a teach-back attempt: the learner explains a saved idea in their own
/// words, an LLM scores whether the *idea* is present and correct, and the score
/// maps to a `ReviewGrade` button for the scheduler.
/// See `research/pivot-2026/memory-system-spec.md` §2c. On-device first
/// (`.appleFoundation`) keeps a daily-loop feature cheap and low-latency.
@MainActor
struct TeachBackGrader {
    var router = LLMRouter.shared

    struct Result: Sendable, Equatable {
        var score: Int            // 0...100
        var missedPoints: [String]
        var feedback: String
        var grade: ReviewGrade
    }

    /// Calls `PromptTemplates.teachBackGrading` via the router, parses the JSON
    /// {score, missedPoints, feedback}, and maps score -> grade. Falls back to a
    /// conservative `.again` result if the model returns unparseable output, so a
    /// daily review never crashes on a bad grade.
    func grade(idea: String, explanation: String) async throws -> Result {
        let (system, user) = PromptTemplates.teachBackGrading(idea: idea, explanation: explanation)
        let req = LLMRequest(
            system: system,
            user: user,
            maxOutputTokens: 600,
            temperature: 0.2,
            model: .appleFoundation
        )
        let resp = try await router.run(.quizGeneration, request: req)
        if let parsed = Self.parseGrade(resp.text) {
            return parsed
        }
        // Graceful fallback: treat an unreadable grade as a failed recall rather
        // than throwing into the review UI.
        return Result(
            score: 0,
            missedPoints: [],
            feedback: "Couldn't grade that attempt — give it another try.",
            grade: .again
        )
    }

    /// Pure mapping: <40 .again, 40...69 .hard, 70...89 .good, >=90 .easy.
    static func grade(forScore score: Int) -> ReviewGrade {
        switch score {
        case ..<40:   return .again
        case 40...69: return .hard
        case 70...89: return .good
        default:      return .easy
        }
    }

    /// Parse the grading JSON defensively, stripping markdown code fences first.
    /// Returns nil on malformed output so callers can fall back. The `grade` field
    /// is derived from `score`, never read from the model.
    static func parseGrade(_ text: String) -> Result? {
        guard let data = stripFences(text).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scoreValue = obj["score"] as? NSNumber
        else { return nil }

        let score = min(100, max(0, scoreValue.intValue))
        let missed = (obj["missedPoints"] as? [Any])?.compactMap { $0 as? String } ?? []
        let feedback = (obj["feedback"] as? String) ?? ""
        return Result(
            score: score,
            missedPoints: missed,
            feedback: feedback,
            grade: grade(forScore: score)
        )
    }

    /// Strip a leading/trailing markdown code fence (```json … ```), mirroring
    /// `ExtractionEngine`'s defensive parsing.
    static func stripFences(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        // Drop the opening fence line (``` or ```json) and the closing fence.
        if let firstNewline = trimmed.firstIndex(of: "\n") {
            trimmed = String(trimmed[trimmed.index(after: firstNewline)...])
        }
        if let fenceRange = trimmed.range(of: "```", options: .backwards) {
            trimmed = String(trimmed[..<fenceRange.lowerBound])
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
