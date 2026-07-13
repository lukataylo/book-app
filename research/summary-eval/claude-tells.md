# Claude-Specific Writing Tells: A Delta on `ai-tells.md`

This file supplements [`ai-tells.md`](./ai-tells.md) and should be read alongside it, not instead of it. `ai-tells.md` documents the generic LLM/AI-writing signature — `delve`, `tapestry`, `underscore`, `pivotal`, "not just X, it's Y," tricolons, uniform sentence length, em-dash overuse, formulaic openers/closers, no-POV vagueness. Nearly everything in that file applies to Claude output as much as to GPT or Gemini output; it is not repeated here.

This file asks a narrower question: **of the tells attributed specifically to Claude (as opposed to "AI" generally), which ones survive scrutiny as actually distinctive, and which are just the generic list with "Claude" written on the label?** The honest answer, after research, is: the vocabulary-level tells are not model-specific at all; a few structural/tonal tendencies (hedging density, validation-opener tics, longer cohesive paragraphs, balanced-both-sides framing) have real, Anthropic-acknowledged roots in how Claude is trained; and rigorous, peer-reviewed evidence that isolates *which specific features* distinguish Claude text from GPT text essentially does not exist yet. Where a claim below rests on a marketing/SEO blog rather than a primary source or peer-reviewed paper, that is flagged explicitly — several of the "Claude tells" circulating online are unverifiable statistics with no visible methodology, and this document treats them accordingly rather than repeating them as fact.

---

## 1. What willfrancis.com's piece actually argues (full extraction)

The one line already quoted in `ai-tells.md` ("Claude: heavier on notably, it's worth noting, longer clausal sentences, more hedging") undersells the piece. Will Francis's article is not a research writeup — it's a practitioner guide with a copy-pasteable Claude Custom Instructions block — and its diagnosis of *why* Claude sounds like Claude is almost entirely a restatement of the generic tells already in `ai-tells.md` §1–2 (empty-impressive vocabulary, false contrasts, throat-clearing, uniform paragraphs, em-dash overuse, the "**Bold term:** explanation sentence" list format, which the piece calls "the single most recognisable AI pattern").[^1]

What is additive, beyond the vocabulary already covered:

**Extra banned-vocabulary items not in `ai-tells.md`'s list:** `dive into`, `bolster`, `unpack`, `shed light on`, `pave the way`, `cutting-edge`, `game-changing`, `multifaceted`, `holistic`.[^1]

**Banned phrases (structural throat-clearing) not already covered:** "When it comes to," "This is where X comes in," "Plays a crucial role in."[^1]

**Concrete mitigation the piece recommends** (for Claude's Settings → Profile → Custom Instructions specifically): vary paragraph lengths deliberately, avoid signposting words, cut sweeping openings/summaries, use contractions, and cap em dashes at one per response.[^1]

The important honesty point: none of this is presented by the author as *empirically Claude-specific* — it's a general AI-tells list that happens to be framed as "how to fix Claude" because Claude is the tool the author uses daily. Treat §1 as confirming there is no strong lexical distinction between Claude tells and generic tells, not as a source of new Claude-only vocabulary signals.

---

## 2. What Anthropic itself documents about Claude's default voice

This is the strongest tier of evidence here, because it's primary-source and dated/versioned rather than a third party's guess.

### 2.1 Claude's system prompt (Anthropic-published, updated per release)

Anthropic has published Claude's system prompts since August 2024, logged at `docs.claude.com/en/release-notes/system-prompts`.[^2] Style-relevant instructions baked directly into the system prompt (as documented by Simon Willison's analysis of the Claude 4 prompt) include:[^3]

- Claude is explicitly told **never** to open a response by calling the user's question/idea "good," "great," "fascinating," "profound," "excellent," or any other positive adjective — a direct countermeasure to the sycophantic-opener tell.
- Claude is told **not** to use filler openers like "Certainly!" or "Absolutely!"
- When declining a request, Claude is instructed not to explain why or what the refusal could lead to, "since this comes across as preachy and annoying."
- Claude is told to avoid lists "in chit chat, in casual conversations, or in empathetic or advice-driven conversations" and to write "in sentences or paragraphs" there instead.
- Claude is told not to ask more than one question per response, to avoid interrogation-style replies.

The significant fact here isn't the specific bullet list — it's that **Anthropic is aware of and actively suppressing several classic AI tells at the system-prompt level** (sycophantic openers, filler enthusiasm, over-listing, over-questioning). This means some tells that show up strongly in *other* models' default output are already partially trained/prompted out of current Claude models, which is one real, sourced reason Claude sometimes reads as less "AI-voiced" than GPT in side-by-side comparisons (see §4).

### 2.2 Anthropic's prompt-engineering documentation

Anthropic's own "Prompting best practices" docs describe Claude's latest models' default communication style directly: "more concise and natural... more direct and grounded... provides fact-based progress reports rather than self-celebratory updates... more conversational... slightly more fluent and colloquial, less machine-like."[^4] This is Anthropic's self-description of a *trend* (older Claude models were more verbose/formal; newer ones less so) — useful context, but it's a company's own characterization of its product, not independent measurement.

The same docs give a concrete, copy-pasteable instruction block Anthropic recommends when developers want Claude to stop defaulting to bullet/bold-heavy output in long-form writing — worth quoting because it doubles as a diagnostic of what Claude does by default absent instruction:

> "When writing reports, documents, technical explanations, analyses, or any long-form content, write in clear, flowing prose using complete paragraphs and sentences... DO NOT use ordered lists (1. ...) or unordered lists (*) unless: a) you're presenting truly discrete items where a list format is the best option, or b) the user explicitly requests a list or ranking... NEVER output a series of overly short bullet points."[^4]

That Anthropic ships this as a *recommended override* is itself evidence that listicle-ification (§2.7 in `ai-tells.md`) is Claude's unguided default, not just a GPT tendency.

Separately, in the frontend-design section of the same doc, Anthropic names the phenomenon "AI slop aesthetic" and explicitly warns that Claude "tend[s] to converge toward generic, 'on distribution' outputs," listing clichéd purple gradients, overused fonts (Inter, Roboto, Arial), and cookie-cutter layouts as the visual analogue of prose tells.[^4] This is Anthropic explicitly naming "on-distribution convergence" as a known failure mode of its own model — the closest thing to an official acknowledgment that Claude has a bland default register it needs active steering away from.

### 2.3 Claude's character training (Amanda Askell / "Claude's Constitution")

Anthropic's character-training work, led by Amanda Askell, is the closest thing to a documented *cause* of Claude's hedging/balance tendencies. Reporting on this work describes Claude 3 as the first model to receive dedicated "character training" aimed at traits like curiosity, open-mindedness, and thoughtfulness, with Askell describing the target persona as "a well-liked traveler who can adjust to local customs... without pandering."[^5] Anthropic's public writeup on this training states that models are deliberately *not* trained to claim false neutrality on contested questions, because doing so "would imply they are more objective and unbiased than they are" — i.e., the both-sides/balanced-framing habit is not purely an emergent RLHF accident but is, in part, a designed response to a different failure mode (false objectivity).[^6] This is a real, citable design rationale — but note it argues Claude's balance-seeking is *intentional*, not merely a hedging artifact, which cuts against treating "balanced framing" as a pure defect the way `ai-tells.md` treats false-balance in GPT output.

---

## 3. Why hedging happens: RLHF mechanics (generic to LLMs, not Claude-exclusive)

Two sourced explanations for *why* models produced by preference-optimization tend toward hedged language — both apply to the RLHF/Constitutional-AI family broadly, not to Claude uniquely, and should not be cited as Claude-specific mechanisms:

- **Constitutional AI's own documented failure modes:** Anthropic's Constitutional AI paper and follow-on analysis note that over-optimized RLHF produces "repetitive phrases, hedging and uninformative answers, self-doubt and over-apologizing, and over-refusals on benign requests."[^7] One constitutional principle explicitly targets moralizing tone: "Choose the assistant response that demonstrates more ethical and moral awareness without sounding excessively condescending, reactive, obnoxious, or condemnatory." This principle is Claude-specific (it's in Claude's constitution), but the failure mode it's counteracting — hedge-stacking under RLHF — is a known property of preference optimization generally, documented across model families.
- **The "Polite Liar" mechanism (2025):** A 2025 paper on epistemic pathology in RLHF-trained language models argues that reward models optimize for perceived sincerity and user satisfaction rather than evidential accuracy, producing a "calibration trap": text that reads as confident or hedged based on what pleases raters, not based on the model's actual internal uncertainty.[^8] This is a general RLHF critique (the paper is not about Claude specifically) but it's the best available mechanistic account of *why* any RLHF-tuned assistant — Claude included — tends to over- or under-hedge in ways decoupled from real confidence.

**Honest framing:** there is no Anthropic-published research isolating a Claude-specific reward-model artifact that produces hedging at a different rate than GPT's RLHF does. What exists is (a) general RLHF hedging theory that applies to all preference-tuned models, and (b) Claude's constitution explicitly targeting *moralizing tone* rather than hedging per se. Anyone citing "Claude hedges more because of Constitutional AI" as a mechanistic claim is going beyond what Anthropic has actually published.

---

## 4. Community claims: Claude vs. GPT, phrase by phrase

Multiple 2025–2026 comparison writeups (marketing blogs, SEO comparison sites, one Hacker News thread) converge on a consistent — but not independently verified — picture. Presented here with source-quality flagged, since this is where false precision is easiest to manufacture.

### 4.1 Claims with moderate corroboration (repeated independently across unrelated sources, consistent with Anthropic's own system-prompt disclosures in §2.1)

- **Lower hedging *relative to GPT-4o*, not lower in absolute terms.** Multiple independent comparison pieces state that GPT-4o "qualifies statements ('it's worth noting that…') even when you don't want that," while Claude "hedges less" and "avoids transition crutches ('Furthermore,' 'It's worth noting that')."[^9] This is the opposite valence from the thin claim already in `ai-tells.md` ("Claude: heavier on... hedging") — the newer consensus (2025–2026, post the Claude 4/4.5 generation) is that Claude has been tuned to hedge *less* than GPT, not more. This is plausible given the system-prompt evidence in §2.1 (explicit suppression of filler/preachy language) and should be treated as a **correction**, not merely an addition, to the one-line claim already in `ai-tells.md` — that line likely reflects an earlier model generation (Claude 3-era) and community perception has shifted since.
- **A validation-opener tic: "You're absolutely right that..."** A Hacker News thread on Claude's tics identifies "You're absolutely right that [X]" as Claude's characteristic self-correction opener, distinct from GPT-5's reported tendency toward "awkward metaphorical" flattery tied to the user's stated profession.[^10] This is specific to conversational/coding contexts (Claude Code, chat) rather than long-form prose, so its relevance to book-summary writing is limited, but it's a genuinely distinguishing, frequently-observed pattern rather than a restated generic tell.
- **Longer, more internally cohesive paragraphs.** Several sources independently describe Claude as producing fewer, longer paragraphs where "each paragraph feels like a mini-essay," versus GPT's shorter, more segmented paragraphs.[^11] This is consistent with Anthropic's own system-prompt instruction to write "in sentences or paragraphs" rather than lists (§2.1), and is structurally distinct from (not just a restatement of) the uniform-paragraph-length tell already covered in `ai-tells.md` §2.4 — the claim isn't about *uniformity*, it's about *paragraph scope/density*.

### 4.2 Claims that are essentially generic tells relabeled "Claude"

- **"It's worth noting," "I should mention," "there's genuine uncertainty here," "that said," "on the other hand"** — cited by several SEO/marketing sources (airno.ai, aitextdetector.ai) as "Claude-characteristic" phrases appearing "at elevated rates compared to GPT-4 or Gemini."[^12][^13] The core problem: `ai-tells.md` §1.1 already lists "important to note" / "it's worth noting" as one of the single highest-signal *generic* AI tells (~3,000x baseline, per Pangram Labs). No source found here provides a comparative frequency measurement (Claude-rate vs. GPT-rate) with visible methodology — the "elevated rate" claim is asserted, not shown. Treat these phrases as generic tells that may *also* appear in Claude output, not as Claude-specific markers.
- **Numbered/lettered internal signposting ("First... Second... Finally...")** — claimed as Claude-characteristic by the same low-rigor sources,[^12] but this is identical to the over-signposting tell already documented in `ai-tells.md` §2.5. No differentiation from GPT is demonstrated.
- **"Uniform sentence rhythm," "lower burstiness than human writing"** — also claimed by the same sources[^12] but this directly contradicts other sources in the same research pass (§4.1, §4.3) claiming Claude has *higher* burstiness/sentence-length variance than GPT. Where sources actively contradict each other on a quantitative claim and neither shows methodology, the honest conclusion is that neither should be trusted, and this document flags both rather than picking a side.

### 4.3 Unverifiable statistics (cited for completeness, explicitly not trusted)

A cluster of SEO/detector-marketing sites (quillbotai.pro, aitextdetector.ai, supwriter.com) cite specific numbers — e.g., "Claude produces 7.1 words of sentence-length variance per paragraph vs. GPT's 4.2," "Claude's average detection rate is 87% vs. ChatGPT's 92%," "Claude's detection score averages 78% with high variance vs. ChatGPT's consistent 94%."[^13][^14][^15] These numbers appear on marketing pages for AI-detection products, with no linked dataset, no described methodology, and mutually inconsistent figures across sites (78% vs. 87% for the same claimed metric). **Do not cite these numbers as fact.** They are included here only so a future researcher doesn't waste time rediscovering and re-evaluating the same low-quality sources. The general *direction* of the claim (Claude text is somewhat harder for current detectors to flag than GPT text) recurs often enough across independent marketing sources to be plausible as a rough trend, but no specific number here should be treated as reliable.

---

## 5. Detection research broken down by model family: the evidence is real but shallow

This is the one academic (arXiv) source found that explicitly separates model families rather than treating "AI text" as one bucket, and it is the most important source in this file precisely because of what it *refuses* to claim.

Ricardo Muñoz Sánchez et al. (or similar; check arXiv listing), "Detecting Stylistic Fingerprints of Large Language Models" (2025), trained an ensemble classifier to distinguish text generated by four LLM families — Claude, Gemini, Llama, and OpenAI models — achieving **99.88% precision** at family-level attribution, and found the fingerprint persists "even when the models are prompted to write in different writing styles."[^16]

The critical honesty point: **the paper explicitly declines to identify which linguistic features drive the classification.** Its own stated limitation: "One main aspect omitted from this research is the investigation of the specific linguistic features and fingerprints that contribute to the predictions." In other words, the strongest available evidence proves Claude-vs-GPT text *is* statistically distinguishable at high confidence — but says nothing about *what* the distinguishing features are. Every specific phrase- or pattern-level claim elsewhere in this document (and in the wider internet) is therefore a guess or an inference from informal comparison, not something backed by the one paper that actually measured family-level separability. No peer-reviewed study located in this research pass closes that gap.

---

## 6. Bottom line: what's actually Claude-specific vs. what isn't

| Claim | Status |
|---|---|
| Claude's system prompt actively suppresses sycophantic openers, filler ("Certainly!"), over-explained refusals, over-listing, and over-questioning | **Well-sourced** — Anthropic-published system prompt, documented by independent analysis[^2][^3] |
| Claude defaults to longer, more cohesive paragraphs and avoids bullets in casual/prose contexts unless instructed otherwise | **Well-sourced** — Anthropic's own prompting docs recommend an override for this exact default[^4] |
| Claude's "balanced both-sides" tendency is partly an intentional design choice (avoiding false objectivity), not purely a hedging artifact | **Well-sourced but contested framing** — Anthropic's own character-training writeup[^6] |
| Newer Claude generations (4/4.5+) hedge *less* than GPT-4o in side-by-side writing comparisons | **Moderately corroborated** — multiple independent 2025–2026 comparison pieces agree; no controlled study[^9] |
| "You're absolutely right that..." as a Claude-specific validation-opener tic | **Anecdotally well-attested** in developer/coding contexts; not measured in prose contexts[^10] |
| Claude-vs-GPT text is distinguishable by a classifier at very high precision | **Academically confirmed**[^16] |
| *Which* specific words/structures make Claude text distinguishable | **Not established by any source found** — the one paper that measured separability explicitly did not identify features[^16] |
| "It's worth noting," "I should mention," "first...second...finally," uniform sentence rhythm as *Claude-specific* markers | **Not established** — these are generic tells already in `ai-tells.md`; sources claiming Claude-specific elevated rates show no methodology and partly contradict each other |
| Specific quantitative detection-rate or variance numbers (78% vs 87% vs 94%; "7.1 words vs 4.2") | **Not trustworthy** — unsourced marketing-page statistics, internally inconsistent across sites |

The generic list in `ai-tells.md` remains the higher-confidence tool for flagging AI-influenced prose regardless of which model produced it. Use this file to (a) know what Anthropic has already engineered out of default Claude output, so you don't waste effort re-flagging things Claude rarely does anymore (sycophantic openers, "Certainly!", excessive bulleting), and (b) stay skeptical of anyone — including this document's own §4.3 sources — who claims precise, differentiated Claude-vs-GPT tells without showing their work.

---

## 7. Quick-Reference Checklist (Claude-specific additions only)

Use this *in addition to* the checklist in `ai-tells.md` §5, not instead of it.

- [ ] Response opens with "You're absolutely right that..." or a structurally similar immediate-validation phrase before a correction (mainly relevant to chat/agentic contexts, less to prose summaries)
- [ ] Paragraphs are few, long, and internally multi-idea ("mini-essay" paragraphs) rather than short and segmented — a Claude-leaning pattern, not itself disqualifying, but worth checking against §2.4 of `ai-tells.md` for uniformity within that longer paragraph
- [ ] "Both sides" framing on a contested claim reads as *deliberately balanced* (substantive counterargument, genuine engagement) rather than *lazily hedged* (strawman then dismissal) — the former is closer to Claude's documented design intent[^6] and is not automatically a flaw; the latter is the generic false-balance tell already in `ai-tells.md` §3.3
- [ ] Extra vocabulary flags beyond `ai-tells.md`'s list, per willfrancis.com: `dive into`, `bolster`, `unpack`, `shed light on`, `pave the way`, `cutting-edge`, `game-changing`, `multifaceted`, `holistic`
- [ ] Extra phrase flags: "When it comes to," "This is where X comes in," "Plays a crucial role in"
- [ ] Treat "it's worth noting" / "I should mention" / "First... Second... Finally..." as **generic** flags (already in `ai-tells.md`), not evidence of Claude specifically — do not double-count them as a separate signal

**What NOT to do:** don't treat unsourced "Claude uses X% more hedges than GPT" statistics as calibration targets. None of the specific numbers found in this research pass held up to scrutiny (see §4.3).

---

## Sources

[^1]: Will Francis, "How to Stop Claude Writing Like an AI," willfrancis.com. Practitioner guide with a copy-pasteable Custom Instructions block; vocabulary list is largely a restatement of generic AI tells. https://willfrancis.com/how-to-stop-claude-writing-like-an-ai/

[^2]: Anthropic, system prompt release notes / changelog, published since August 2024 and updated with every model release. https://docs.claude.com/en/release-notes/system-prompts

[^3]: Simon Willison, "Highlights from the Claude 4 system prompt," 2025 — independent close-reading of Anthropic's published Claude 4 system prompt, including style/tone instructions. https://simonwillison.net/2025/May/25/claude-4-system-prompt/

[^4]: Anthropic, "Prompting best practices," Claude Platform Docs — includes Anthropic's own characterization of Claude's default communication style, a recommended prose-vs-bullets override block, and the "AI slop aesthetic" / "on-distribution convergence" framing for frontend defaults. https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices

[^5]: Reporting on Amanda Askell's character-training work at Anthropic (head of the finetuning/personality-alignment work informing Claude 3 onward). https://www.bigtechnology.com/p/how-anthropic-builds-claudes-personality — https://en.wikipedia.org/wiki/Amanda_Askell

[^6]: Anthropic, "Claude's Character," June 2024, discussed by Simon Willison. Documents the design rationale for balanced/non-falsely-neutral framing on contested questions. https://simonwillison.net/2024/Jun/8/claudes-character/

[^7]: Anthropic, "Constitutional AI: Harmlessness from AI Feedback," arXiv:2212.08073, Dec 2022; and secondary analysis of RLHF over-optimization failure modes (hedging, over-apologizing, over-refusal). https://arxiv.org/pdf/2212.08073 — https://valueaddvc.com/blog/constitutional-ai-explained-what-anthropics-safety-approach-actually-means

[^8]: Bentley DeVilling (Course Correct Labs), "The Polite Liar: Epistemic Pathology in Language Models," arXiv:2511.07477, Nov 2025. General RLHF critique, not Claude-specific; argues reward models optimize for perceived sincerity over evidential accuracy, producing a "calibration trap." https://arxiv.org/abs/2511.07477

[^9]: Multiple 2025–2026 comparison writeups converging on "Claude hedges less than GPT-4o" as the current-generation consensus; no controlled study located. https://www.mindstudio.ai/blog/chatgpt-vs-claude-2026-which-to-use — https://sureprompts.com/blog/chatgpt-vs-claude-2026 — https://blog.type.ai/post/claude-vs-gpt

[^10]: Hacker News discussion, "Claude says 'You're absolutely right!' about everything," identifying the validation-opener tic and contrasting it with GPT-5's reported flattery style. https://news.ycombinator.com/item?id=44885398

[^11]: Community writeups describing Claude's tendency toward fewer, longer, more internally cohesive paragraphs vs. GPT's shorter segmented paragraphs; corroborated in direction by Anthropic's own prose-vs-bullets prompting guidance (see [^4]) but not independently measured. https://blog.type.ai/post/claude-vs-gpt

[^12]: Airno.ai, "Claude AI Detector: How to Tell If Text Was Written by Claude" — marketing content for an AI-detection product; claims are asserted without visible methodology and partly contradict other sources on burstiness. https://www.airno.ai/blog/claude-ai-detector

[^13]: AITextDetector.ai, "ChatGPT vs Claude vs Gemini: Which AI Writing Tool Is Hardest to Detect?" — marketing content for a detection product; cites specific detection-rate percentages with no described dataset or methodology. https://aitextdetector.ai/chatgpt-vs-claude-vs-gemini-detection/

[^14]: SupWriter, "ChatGPT vs Claude vs Gemini: AI Detection" — marketing content citing detection-rate percentages inconsistent with [^13] for the same claimed metric. https://supwriter.com/blog/which-ai-hardest-to-detect

[^15]: QuillBotAI Pro, "How to Detect Claude AI Writing in 2026 — Patterns, Tools, and Accuracy Data" — marketing content citing a specific "7.1 vs 4.2 words of sentence-length variance" statistic with no visible source data.

[^16]: "Detecting Stylistic Fingerprints of Large Language Models," arXiv:2503.01659, 2025. Ensemble classifier achieves 99.88% precision distinguishing Claude/Gemini/Llama/OpenAI-generated text; explicitly does not identify which linguistic features drive the classification. https://arxiv.org/html/2503.01659v1

---

## Summary (5-Line Version)

1. **Most "Claude tells" circulating online are generic AI tells with a Claude label stuck on them** — vocabulary lists, "it's worth noting," signposting — all already covered in `ai-tells.md`; no source here demonstrates Claude uses them at a different rate than GPT with real methodology.
2. **The strongest evidence is Anthropic's own system prompt and prompting docs**, which show Claude is actively trained/prompted away from sycophantic openers, filler ("Certainly!"), over-explained refusals, and unrequested bullet lists — meaning some generic AI tells are now *less* likely in Claude output than in other models.
3. **Claude's balanced/both-sides tendency has a documented design rationale** (avoiding false neutrality on contested questions), not just an RLHF hedging accident — though general RLHF hedging theory (the "Polite Liar" mechanism) still plausibly applies to Claude as to any preference-tuned model.
4. **Academic evidence confirms Claude-vs-GPT text is statistically distinguishable at very high precision (99.88%) but explicitly does not say by what features** — the feature-level gap this document was asked to fill remains genuinely open in the literature.
5. **Treat all specific Claude-vs-GPT percentage statistics found in marketing/SEO sources as unverified** — several are internally inconsistent across sources and none show methodology; the "You're absolutely right," longer-cohesive-paragraph, and less-hedging-than-GPT4o patterns are the only community claims with any cross-source, non-contradicted corroboration.
