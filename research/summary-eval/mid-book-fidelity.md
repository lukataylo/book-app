# Mid-Book Fidelity — Generator Design + Eval for Full-Length Summaries

**Scope:** full elastic-length book transformations (`TransformationEngine` / the compress-expand
pipeline that runs over a user's or the catalog's complete book text via `Chunker.swift`) — not
the short `summary_short`/`summary` catalog fields, which are covered by [`SKILL.md`](./SKILL.md).
This file is about a different failure mode than SKILL.md's: not *sounding like AI*, but
*forgetting the middle of the book* once the input is too long for one context window. Both
failure modes compound in practice — apply this file's pipeline/eval, then apply SKILL.md's voice
rules (plus [`claude-tells.md`](./claude-tells.md)) to whatever prose comes out of it.

**Built from:**
- [`long-context-summarization.md`](./long-context-summarization.md) — the literature (Lost in
  the Middle, BooookScore, Chain of Density, recursive book summarization, 2024–2025 follow-ups)
- [`human-fulltext/`](./human-fulltext/) — four books' worth of human-written mid-book summaries,
  benchmarked specifically for what a human writer does differently once they're past the
  opening hook
- [`ai-tells.md`](./ai-tells.md) + [`claude-tells.md`](./claude-tells.md) — voice, applied on top
- `Chunker.swift`, `TransformationEngine.swift` — the actual pipeline this targets

---

## 1. The problem, in one paragraph

LLMs have a well-documented, robust U-shaped recall curve over long contexts: best at the start
and end of whatever they're reading, worst in the middle.[^lim] Chunking a book doesn't fix
this — it just moves the same bias up a level, into whichever step *combines* chunk outputs back
together. This app's current pipeline chunks the book (good), transforms each chunk
independently (fine), then joins the results with only local seam-smoothing at each boundary —
there is no real reduce/merge step that checks whether content from the book's middle survived
into the final output. That gap is exactly where BooookScore found Claude 2 systematically
"omits key information present in the beginning or middle of the input... in favor of focusing
on the end of the book."[^bs] The fix is architectural (a real reduce step that carries facts
forward and gets audited), not a prompting trick layered on top of the current join.

---

## 2. Generator pipeline

Condensed from `long-context-summarization.md`'s full pipeline sketch — see that file for the
literature backing each step.

1. **Chunk as today.** No change — `Chunker.swift`'s chapter-boundary-aware chunking isn't the
   bottleneck.
2. **Per-chunk fact/claim extraction, before compression.** For each chunk: named entities, key
   claims/events, and a position tag (which third of the book). A small structured artifact per
   chunk, not just prose.
3. **Chapter-level merges that carry a fact ledger forward**, not just adjacent-chunk prose.
   Merge 2–4 chunks at a time — never everything at once — and pass each merge step the running
   ledger of entities/claims extracted so far, not just the neighboring chunk's text. This is the
   single highest-leverage fix identified in the literature (Context-Aware Hierarchical
   Merging[^cahm]): merge steps that operate blind to earlier context are what let hallucination
   and omission compound across the tree.
4. **Coverage-checklist pass before final synthesis.** Cross-reference the merged fact ledger
   (tagged by book-third) against the current draft: which middle-third facts are *not* reflected?
   Beginning/end coverage is the default bias, so this check should specifically target the
   middle third — that's the one place the model won't self-correct for free.
5. **Final synthesis with position-structured prompting.** Source content before instructions,
   generation instruction at the end (Anthropic's own long-context guidance measures this at up
   to +30% response quality[^anthropic-lc]); keep the generation call itself short in output
   length, since faithfulness also degrades toward the *end of a long generated response*, a
   distinct output-side drift effect.[^hall]
6. **Proportionality check as a hard gate**, not just an offline metric — run the positional
   recall check (§4 below) before persisting a variant, and if middle-third recall lags, trigger
   one targeted revision scoped to "add coverage of these specific missing facts without
   expanding length" (mirroring Chain of Density's fixed-length densification[^cod]).

The existing seam-rewrite step stays — it helps prose flow at chunk boundaries — but it isn't a
substitute for steps 3–4. It only ever sees ~800 characters on either side of one boundary and
has no visibility into whole-book coverage.

---

## 3. Prose rules for the middle specifically

Ten human-benchmark-derived rules (full detail and per-book evidence in
[`human-fulltext/_index.md`](./human-fulltext/_index.md)) — apply these to whatever the pipeline
in §2 produces, as a content/structure layer underneath SKILL.md's voice layer:

1. **Compress callbacks, don't restate them.** A single clause referencing the opening thesis is
   enough ("Harari's imagined orders show up again here as...") — re-explaining the thesis is
   padding and a coherence tell, not a fidelity win.
2. **Mirror the source's own structure.** Follow the book's actual chapters/parts/named
   frameworks instead of inventing new connective tissue — this is a concrete, checkable signal:
   a summary that names the book's own taxonomy is measurably more likely to have covered the
   material behind it.
3. **The middle should read cooler and denser, not flatter.** Reserve superlatives for the
   opening hook and the close; the middle carries names, dates, numbers, and causal chains.
4. **State causal function next to the event.** Don't just report that something happened in the
   middle — say what it caused or why it mattered, in the same sentence.
5. **Tolerate open loops across large spans.** A thread introduced mid-book and resolved much
   later should stay open in the summary, not get force-closed early or silently dropped.
6. **Use named entities/concrete objects as continuity anchors**, and keep them consistent. Their
   disappearance between mentions is a cheap, checkable proxy for "the summarizer lost the
   middle."
7. **Write for comprehension, not persuasion, when covering the middle.** Promotional framing
   structurally cannot survive contact with a book's middle (see mans-search-for-meaning) — an
   explicit instruction to cover the middle "as if for a reader who wants to understand it," not
   "as if to sell it," resists this.
8. **Convert extended arcs into an explicit, small taxonomy** ("three phases," not one flattening
   sentence) — a faithful compression technique, not a cop-out.
9. **Promote exactly one load-bearing scene from the middle to full narrative treatment**, rather
   than spreading thin, uniform coverage across everything. Proportional word count is not the
   same as proportional information recall (see §4).
10. **Paraphrase the middle; quote the bookends.** Verbatim/near-verbatim treatment belongs on the
    famous opening and closing lines. The middle should read as digested and interpreted, in the
    summary's own words — legally safer for this app's copyrighted-book catalog too (see
    `PLAN.md` §3's IP guidance, which already mandates original wording throughout).

---

## 4. Eval: positional recall

**Goal:** a repeatable check for whether a summary demonstrably under-represents the middle
third of a book's *information*, independent of its raw word-count allocation — a summary can
mention the middle third proportionally by length while still failing to convey what's actually
in it.

**Protocol** (full detail in `long-context-summarization.md` §"Proposed Eval Methodology"):

1. **Build a positional fact set per eval book, once.** Split the source into thirds by
   token/character count. Extract ~15–20 verifiable, specific facts per third via an LLM pass
   tuned for specificity — reuse this repo's existing "a fact should be something a reader could
   look up" bar from `ai-tells.md`. Spot-check a sample by hand so the fact set itself is a
   trusted, reusable fixture.
2. **Score recall per summary.** For each fact, an LLM-judge call determines whether the summary
   demonstrably reflects it (binary, or 0/0.5/1 for finer resolution). Aggregate into
   `recall_first_third`, `recall_middle_third`, `recall_last_third`.
3. **Compute the gap.** `positional_recall_gap = recall_middle_third / mean(recall_first_third,
   recall_last_third)`. Near 1.0 = proportional coverage; well below (tune the threshold against
   a baseline distribution, ~0.7 as a starting point) = a "forgot the middle" failure.
4. **Make it CI-friendly.** Both steps are single structured-output LLM calls — script them the
   same way `eval-results.md`'s scoring conventions already work in this repo, and track
   `positional_recall_gap` as a first-class regression metric alongside prose-quality/AI-tell
   scores, so a change that improves fluency but quietly worsens middle coverage gets caught. Run
   against a fixed panel varying length/genre/chapter-marker structure (structured vs.
   unstructured source text hits the chunker differently). For an in-app pre-persist gate, use a
   cheaper variant (5 facts/third instead of 15–20).

**Caveat, stated plainly:** no established published benchmark implements exactly this protocol —
it's a synthesis of BooookScore's omission taxonomy and LongFormFact's position-perturbation
methodology, not a reproduction of either. Pilot it on the 4-book panel in `human-fulltext/`
before trusting it as a hard release gate, and calibrate the 0.7 threshold against real output
rather than treating it as given.

**Human-benchmark cross-check.** Beyond the automated recall metric, spot-check generated middle
sections against `human-fulltext/`'s ten structural rules (§3) — the recall metric catches *what*
got dropped; the human-benchmark comparison catches *how* the middle is written once it's there
(cooler register, causal adjacency, entity continuity), which a fact-presence check alone won't
surface.

**Runnable harness.** [`scripts/mid-book-eval.py`](../../scripts/mid-book-eval.py) implements
this protocol (`facts` → `score` → `report`, or `run` for one-shot), reusing
`seed-transform.py`'s Claude-call/Keychain helpers. It's validated end-to-end against a real,
public-domain full-length book in
[`mid-book-eval-demo/`](./mid-book-eval-demo/README.md) — two candidate Crime and Punishment
summaries (one with the classic beginning/end-heavy shape, one that preserves the middle's three
parallel plot threads) score `positional_recall_gap` of 0.15 (FAIL) and 1.00 (PASS)
respectively, confirming the metric actually discriminates the failure mode it's meant to catch.

---

## 5. What this file does not cover

- **Voice/AI-tell removal** — see `SKILL.md` + `ai-tells.md` + `claude-tells.md`. A summary can
  pass every check in this file and still sound like AI; the two layers are independent and both
  required.
- **The short `summary_short`/`summary` catalog fields** — those are generated from editorial
  knowledge of a book, not from chunking full book text, so lost-in-the-middle doesn't apply the
  same way. This file is specifically for the `TransformationEngine` compress/expand path over
  complete book text (per `PLAN.md`, the same engine that's slated to generate catalog summaries
  going forward — at that point this file's scope and the catalog eval in `eval-results.md`
  converge, and the two should be run together).
- **Legal/IP review of generated output** — see `PLAN.md` §3 and `docs/content-legal-review.md`.
  Rule 10 above (paraphrase, don't quote, the middle) is a fidelity rule that happens to also
  help on the legal side, not a substitute for that review.

---

## Sources

See full citations in [`long-context-summarization.md`](./long-context-summarization.md) and
[`claude-tells.md`](./claude-tells.md). Key ones referenced directly above:

[^lim]: Liu et al., "Lost in the Middle: How Language Models Use Long Contexts," TACL 2024. https://arxiv.org/abs/2307.03172
[^bs]: Chang et al., "BooookScore," ICLR 2024 (Oral). https://arxiv.org/abs/2310.00785
[^cahm]: Ou & Lapata, "Context-Aware Hierarchical Merging for Long Document Summarization," ACL Findings 2025. https://arxiv.org/abs/2502.00977
[^anthropic-lc]: Anthropic, long-context prompting guidance. https://platform.claude.com/docs/en/docs/build-with-claude/prompt-engineering/long-context-tips
[^hall]: "Hallucinate at the Last in Long Response Generation," 2025. https://arxiv.org/abs/2505.15291
[^cod]: Adams et al., "Chain of Density," EMNLP 2023. https://arxiv.org/abs/2309.04269
