import Foundation

/// Generates recall cards from saved insights and reformulates leeches.
/// See `research/pivot-2026/memory-system-spec.md` §2b (cloze/Q&A) and §3c
/// (leech reformulation). Routes on-device first (`.appleFoundation`) at low
/// temperature so card generation stays cheap and deterministic enough to reuse.
@MainActor
struct CardGenerator {
    var router = LLMRouter.shared

    struct Cloze: Sendable, Equatable {
        var front: String       // full prompt/sentence
        var back: String        // the answer (the blanked span, or a short answer)
        var clozeMask: String   // the exact substring of `front` that is blanked; "" for Q&A
    }

    /// Generate a cloze (or short Q&A) card from an insight. Falls back to a plain
    /// Q&A (front="What is the key idea here?", back=idea) if the model returns
    /// malformed output, so saving an insight always yields a usable card.
    func makeCloze(idea: String) async throws -> Cloze {
        let (system, user) = PromptTemplates.clozeFromIdea(idea)
        let req = LLMRequest(
            system: system,
            user: user,
            maxOutputTokens: 400,
            temperature: 0.2,
            model: .appleFoundation
        )
        let resp = try await router.run(.quizGeneration, request: req)
        if let cloze = Self.parseCloze(resp.text) {
            return cloze
        }
        return Self.fallback(idea: idea)
    }

    /// Rewrite a leech into a clearer/simpler card, given the failed attempts.
    /// Falls back to the same plain Q&A as `makeCloze` if the model misbehaves.
    func reformulate(idea: String, failedAttempts: [String]) async throws -> Cloze {
        let (system, user) = PromptTemplates.reformulateCard(idea: idea, failedAttempts: failedAttempts)
        let req = LLMRequest(
            system: system,
            user: user,
            maxOutputTokens: 400,
            temperature: 0.2,
            model: .appleFoundation
        )
        let resp = try await router.run(.quizGeneration, request: req)
        if let cloze = Self.parseCloze(resp.text) {
            return cloze
        }
        return Self.fallback(idea: idea)
    }

    /// The graceful fallback card: a plain Q&A built straight from the idea.
    static func fallback(idea: String) -> Cloze {
        Cloze(front: "What is the key idea here?", back: idea, clozeMask: "")
    }

    /// Parse a card JSON {"front","back","clozeMask"} defensively, stripping
    /// markdown fences first. Returns nil on garbage so callers can fall back.
    /// A model-supplied `clozeMask` is honored only when it's an exact substring
    /// of `front`; otherwise it's recomputed from `back` (or cleared for Q&A).
    static func parseCloze(_ text: String) -> Cloze? {
        guard let data = TeachBackGrader.stripFences(text).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let front = obj["front"] as? String,
              let back = obj["back"] as? String,
              !front.isEmpty
        else { return nil }

        let suppliedMask = (obj["clozeMask"] as? String) ?? ""
        let resolvedMask: String
        if !suppliedMask.isEmpty, front.contains(suppliedMask) {
            resolvedMask = suppliedMask
        } else {
            resolvedMask = mask(for: back, in: front)
        }
        return Cloze(front: front, back: back, clozeMask: resolvedMask)
    }

    /// Returns `answer` if it appears verbatim in `front` (so the review UI can
    /// blank that span), else "" — meaning treat the card as a short Q&A.
    static func mask(for answer: String, in front: String) -> String {
        guard !answer.isEmpty, front.contains(answer) else { return "" }
        return answer
    }
}
