import Foundation

/// Prompt templates for every transformation. Centralized so behavior is
/// auditable in one place. The source text is passed separately from the
/// system+user prompt pair so it can be cached on the cloud provider and
/// streamed cleanly into the chunker.
///
/// Design principles for every prompt here:
///
/// 1. **No meta-commentary.** Models love to say "I have rewritten the
///    passage in the style of …" or "Here is the compressed version:".
///    Every system prompt explicitly bans that; the model should output
///    only the rewritten prose.
/// 2. **No invented facts.** Even on expansion, the rule is to elaborate
///    on what's already there — examples, analogies, context — never to
///    add propositions the source didn't make. This keeps transformations
///    trustworthy.
/// 3. **Tone is structural.** Compression and expansion both preserve the
///    original's voice; only the explicit `.styled` task changes it. The
///    model is told *which* features of the voice to copy (sentence
///    rhythm, vocabulary register, rhetorical moves) so it has something
///    concrete to imitate.
/// 4. **Paragraph structure matters.** Broken paragraphs make EPUB
///    rendering ugly. Every prompt enforces blank-line separators and
///    forbids markdown code fences, ASCII chunk markers, etc.
/// 5. **Robust to bad chunks.** Chunks may begin or end mid-sentence.
///    Prompts tell the model to mirror that behavior in its output so the
///    seam-rewrite step has consistent input to work with.
enum PromptTemplates {

    static func categoryTagging(title: String, author: String, sample: String) -> (system: String, user: String) {
        let system = """
        You categorize books for a personal library.

        Output strictly valid JSON of the form:
        {"categories": ["...", "..."], "themes": ["...", "..."]}

        - 1–3 broad categories. Use canonical labels: Philosophy, Politics, History, \
        Self-improvement, Business, Science, Fiction, Poetry, Religion, Psychology, \
        Memoir, Essays, Reference. Combine when appropriate (e.g. ["Philosophy", "Politics"]).
        - 3–8 specific themes — concrete enough to actually search by. Prefer \
        "habit formation" over "habits", "stoic acceptance" over "stoicism".
        - No commentary, no markdown code fences, no leading prose. JSON only.
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

        Each learning is one or two crisp sentences capturing an idea the \
        reader should retain. Prefer:
        - Specific propositions over platitudes ("Cruelty inflicted in one \
        decisive stroke is forgiven faster than cruelty drawn out" beats \
        "Be careful with cruelty").
        - Direct paraphrase of the author's argument over your interpretation.
        - Active voice, present tense.

        Output strictly valid JSON, an array of objects:
        [{"text": "...", "chapter": "..."}, ...]

        - "chapter" is the chapter title or roman-numeral if present in the \
        source; empty string otherwise. Do not invent chapter labels.
        - No commentary, no markdown code fences. JSON only.
        """
        return (system, "Book content:\n\(book)")
    }

    static func quizFromLearnings(_ learnings: [String]) -> (system: String, user: String) {
        let system = """
        Turn these key learnings into flashcards.

        Output strictly valid JSON, an array of objects:
        [{"q": "...", "a": "..."}, ...]

        - One card per learning, in the same order.
        - Front (q): a question that probes the *idea*, not its phrasing. \
        Avoid "What does the author say about …?" — prefer "Why is X riskier \
        than Y?".
        - Back (a): one or two sentences that fully answer the question.
        - No commentary, no markdown. JSON only.
        """
        return (system, learnings.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n"))
    }

    /// Map step prompt — applied per chunk during compression / expansion /
    /// style transfer. `targetRatio` is the desired output length as a
    /// fraction of the chunk's input length (0.25 = compress to a quarter,
    /// 1.5 = expand by 50%).
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
            directives.append("""
            Compress this chunk to approximately \(Int(targetRatio * 100))% of its length.
            Preserve every load-bearing argument, the order of ideas, and the \
            author's voice — sentence rhythm, vocabulary register, rhetorical \
            moves. Cut redundancy and elaboration; keep claims, evidence, and \
            transitions. Do not summarize from the outside — rewrite from \
            inside the author's perspective.
            """)
        case .expanded:
            directives.append("""
            Expand this chunk to approximately \(Int(targetRatio * 100))% of its length.
            Elaborate on existing claims with examples, analogies, and \
            clarifying restatements drawn from the chunk itself. \
            Do NOT introduce new claims, facts, dates, names, statistics, \
            or arguments the source does not make — that is hallucination. \
            Preserve the author's voice exactly.
            """)
        case .styled:
            let ref = styleReference.isEmpty ? "the requested author" : styleReference
            directives.append("""
            Rewrite this chunk in the prose style of \(ref). Preserve every \
            argument, claim, and structural beat from the source — only the \
            voice changes.
            Imitate \(ref)'s characteristic moves: sentence rhythm, paragraph \
            shape, vocabulary register, signature rhetorical devices, \
            stance toward the reader. Do not parody — reproduce.
            """)
        case .themeOmitted:
            directives.append("""
            Omit any content related to these themes: \(omittedThemes.joined(separator: ", ")).
            Bridge over the cuts so the prose still flows — short, voice-matched \
            transitions are fine; do NOT leave abrupt gaps or chapter stubs.
            Preserve everything else verbatim wherever possible.
            """)
        case .original:
            directives.append("Return the chunk verbatim. No edits, no commentary.")
        }

        if kind != .themeOmitted, !omittedThemes.isEmpty {
            directives.append("Also omit content related to: \(omittedThemes.joined(separator: ", ")). Bridge smoothly over removals.")
        }

        directives.append("Preserve paragraph breaks (blank line between paragraphs) and any heading lines starting with `# `.")
        directives.append("If the chunk begins or ends mid-sentence, mirror that in the output — do NOT round it off.")

        let system = """
        You are rewriting one chunk of a long book. This is chunk \
        \(chunkIndex + 1) of \(chunkCount).

        Directives:
        - \(directives.joined(separator: "\n- "))

        Output rules — non-negotiable:
        - Return ONLY the rewritten prose. No preamble ("Here is …"), no \
        afterword ("I have rewritten …"), no chunk markers, no metadata, \
        no markdown code fences (```), no headings you invented.
        - Use blank lines between paragraphs. No tabs, no leading bullets \
        unless the source had them.
        - If you cannot follow a directive (e.g. the chunk is too short to \
        compress further), output the chunk unchanged rather than \
        explaining the situation.
        """

        let user = "Source chunk follows."
        return (system, user)
    }

    /// Reduce step — rewrites the seam between two adjacent transformed
    /// chunks so the joined output reads continuously.
    static func seamRewrite() -> (system: String, user: String) {
        let system = """
        You are joining two adjacent passages from a transformed book. The \
        last paragraph of the first passage and the first paragraph of the \
        second often read awkwardly because they were generated independently.

        Rewrite ONLY those two paragraphs so the join flows continuously:
        - Preserve every idea and detail from both originals.
        - Match the surrounding voice — do not introduce new tone.
        - Do not modify any other text.

        Output strictly valid JSON:
        {"left": "<rewritten last paragraph of first passage>", \
        "right": "<rewritten first paragraph of second passage>"}

        No commentary, no code fences. JSON only.
        """
        let user = "Two adjacent passages will follow."
        return (system, user)
    }

    /// Final polish pass when the full output fits in context.
    static func polishWhole(kind: VariantKind, styleReference: String) -> (system: String, user: String) {
        var directive = """
        Light editing pass on the manuscript that follows.
        - Fix paragraph-level repetitions and redundant restatements.
        - Smooth abrupt transitions between sections.
        - Ensure consistent tense, person, and voice throughout.
        - Do NOT change arguments, add facts, or remove ideas.
        """
        if kind == .styled, !styleReference.isEmpty {
            directive += """

            Re-check that the prose genuinely sounds like \(styleReference). \
            Replace any voice-flat phrasing with phrasing that fits \
            \(styleReference)'s established style.
            """
        }
        let system = """
        \(directive)

        Output rules:
        - Return ONLY the polished manuscript. No commentary, no preamble.
        - Preserve paragraph breaks (blank line between paragraphs) and \
        heading lines starting with `# `.
        - No markdown code fences.
        """
        return (system, "Manuscript follows.")
    }

    static func chatWithBook(question: String) -> (system: String, user: String) {
        let system = """
        Answer the user's question about the book strictly from its content.

        Rules:
        - Quote or paraphrase the relevant passage when you can; cite the \
        chapter or section name if the source provides one.
        - If the answer isn't in the book, say so plainly: "The book \
        doesn't address that." Do not speculate or fill in from general \
        knowledge.
        - Keep the response under 200 words unless the user asks for more.
        - Match the user's register — concise question → concise answer.
        """
        return (system, "Question: \(question)")
    }
}
