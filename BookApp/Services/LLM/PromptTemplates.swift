import Foundation

/// Prompt templates for every transformation. Centralized so behavior is auditable
/// in one place. Each function returns the complete request payload (system + user)
/// and the source text is passed separately so it can be cached on the cloud provider.
enum PromptTemplates {

    static func categoryTagging(title: String, author: String, sample: String) -> (system: String, user: String) {
        let system = """
        You categorize books for a personal library.
        Reply with JSON: {"categories": ["...", "..."], "themes": ["...", "..."]}
        Use 1–3 broad categories (e.g. Self-improvement, Philosophy, Business, Science Fiction).
        Use 3–8 specific themes (e.g. habit formation, stoicism, Bayesian thinking).
        No commentary. JSON only.
        """
        let user = """
        Title: \(title)
        Author: \(author)
        Sample (first ~2000 chars):
        \(sample)
        """
        return (system, user)
    }

    static func keyLearnings(book: String, count: Int = 10) -> (system: String, user: String) {
        let system = """
        Extract \(count) key learnings from the book provided.
        Each learning is one or two crisp sentences capturing an idea the reader should retain.
        Reply as JSON array: [{"text": "...", "chapter": "..."}, ...]
        Prefer concrete, actionable points over high-level platitudes. JSON only — no commentary.
        """
        return (system, "Book content:\n\(book)")
    }

    static func quizFromLearnings(_ learnings: [String]) -> (system: String, user: String) {
        let system = """
        Turn these key learnings into flashcards.
        Reply as JSON array: [{"q": "...", "a": "..."}, ...]
        One card per learning. Front is a question that probes the idea; back is a 1–2 sentence answer.
        """
        return (system, learnings.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n"))
    }

    /// Map step prompt — applied per chunk during compression / expansion / style transfer.
    static func transformChunk(
        kind: VariantKind,
        targetRatio: Double,
        styleReference: String,
        omittedThemes: [String],
        chunkIndex: Int,
        chunkCount: Int
    ) -> (system: String, user: String) {
        var directives: [String] = []

        switch kind {
        case .compressed:
            directives.append("Compress to ~\(Int(targetRatio * 100))% of the original length.")
            directives.append("Preserve the author's voice, narrative beats, and key arguments.")
        case .expanded:
            directives.append("Expand to ~\(Int(targetRatio * 100))% of the original length.")
            directives.append("Add depth: examples, analogies, gentle elaboration. Do not invent facts.")
        case .styled:
            directives.append("Rewrite in the style of \(styleReference) while preserving every key idea, argument, and structural beat from the source.")
            directives.append("Match \(styleReference)'s sentence rhythm, vocabulary register, and rhetorical moves.")
        case .themeOmitted:
            directives.append("Omit any content related to these themes: \(omittedThemes.joined(separator: ", ")).")
            directives.append("Smoothly bridge over the removed material — do not leave abrupt gaps.")
        case .original:
            directives.append("Return the chunk verbatim.")
        }

        if kind != .themeOmitted, !omittedThemes.isEmpty {
            directives.append("Also omit content related to: \(omittedThemes.joined(separator: ", ")).")
        }

        let system = """
        You are rewriting one chunk of a long book.
        This is chunk \(chunkIndex + 1) of \(chunkCount).
        Directives:
        - \(directives.joined(separator: "\n- "))
        - Output only the rewritten prose — no preamble, no chunk markers, no commentary.
        - Keep paragraph breaks and section headings if present.
        - If the chunk begins or ends mid-sentence, mirror that in the output.
        """

        let user = "Source chunk follows."
        return (system, user)
    }

    /// Reduce step — rewrites the seam between two adjacent transformed chunks
    /// so the joined output reads continuously.
    static func seamRewrite() -> (system: String, user: String) {
        let system = """
        You are joining two adjacent passages from a transformed book.
        Rewrite the last paragraph of the first passage and the first paragraph of the second
        so they flow continuously, preserving every idea from both.
        Output JSON: {"left": "...", "right": "..."} with the rewritten paragraphs only.
        Do not modify any other text.
        """
        let user = "Two adjacent passages will follow."
        return (system, user)
    }

    /// Final polish pass when the full output fits in context.
    static func polishWhole(kind: VariantKind, styleReference: String) -> (system: String, user: String) {
        var directive = "Light editing pass — fix repetitions, smooth transitions, ensure consistent tense and voice."
        if kind == .styled, !styleReference.isEmpty {
            directive += " Re-check that the prose sounds genuinely like \(styleReference)."
        }
        let system = """
        \(directive)
        Output only the polished prose. No commentary.
        """
        return (system, "Manuscript follows.")
    }

    static func chatWithBook(question: String) -> (system: String, user: String) {
        let system = """
        Answer the user's question about the book strictly from its content.
        If the answer isn't in the book, say so plainly.
        """
        return (system, "Question: \(question)")
    }
}
