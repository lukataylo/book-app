# Summary Writing-Quality Eval — Definitive Results

**Date:** 2026-06-15
**Scope:** The 8 shipped `summary_short` fields (the reader-facing hook shown before the full summary), scored against an absolute rubric and diagnosed against human-written benchmarks.
**Inputs:** `BookApp/Resources/SummaryPacks/<slug>.json` (`summary_short`); `research/summary-eval/human/<slug>.md`; rubrics `ai-tells.md` + `engaging-summaries.md`.
**Supersedes:** the prior (sonnet) pass. Disagreements with it are flagged inline as **[CORRECTION]**.

## Methodology

- **Absolute-rubric, not blinded.** The evaluator read the rubric sources and the human benchmarks before scoring. Scores reflect how well each text satisfies the criteria, not a relative curve against the benchmarks. A perfectly human-sounding summary could score 30/30; benchmarks are used diagnostically, not as a ceiling. The evaluator knew which texts were ours — this is a known bias, partially mitigated by anchoring every sub-score to a quoted fragment and every tell-claim to a machine count.
- **Counts are real.** Em-dashes, words, sentence-length distributions, semicolons, and three-or-more-item comma lists were counted programmatically per `summary_short`. Where the prior pass asserted a frequency, it was re-counted. The em-dash "ideal" is `ai-tells.md`'s own threshold: ~1 per 300 words is human; 3+ per 300 is a signal.
- **Sub-scores 0–5** on: (a) thesis-first hook, (b) concreteness / named real examples, (c) authorial POV & stated limits, (d) voice & sentence-rhythm variety, (e) freedom from AI-tells, (f) close that motivates reading the **book** (not our longer summary).

## Verified measurements (per `summary_short`)

| Book | Words | Em-dashes | Em/300w | 3+ item lists | Sentences | Avg len | Shortest sent |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| atomic-habits | 355 | 6 | **5.07** | 6 | 11 | 32.3 | 15 |
| sapiens | 313 | 5 | 4.79 | 3 | 13 | 24.1 | 10 |
| thinking-fast-and-slow | 319 | **0** | **0.00** | 3 | 12 | 26.6 | 7 |
| the-psychology-of-money | 344 | 7 | **6.10** | 1 | 10 | 34.4 | 20 |
| mans-search-for-meaning | 341 | 5 | 4.40 | 4 | 10 | 34.1 | 25 |
| deep-work | 339 | 3 | 2.65 | 6 | 10 | 33.9 | 8 |
| the-body-keeps-the-score | 371 | 5 | 4.04 | 6 | 11 | 33.7 | 8 |
| never-split-the-difference | 336 | 5 | 4.46 | 4 | 11 | 30.5 | 6 |

**Meta-close "The full summary…" formula: present in 8 of 8.** Every summary ends by directing the reader to *our* longer summary. (Prior pass said 6 of 8 — **[CORRECTION]**: it is universal, and is therefore the catalog's single most systematic tell, ahead of the tricolon.)

## Scored table

| Book | (a) Hook | (b) Concrete | (c) POV | (d) Rhythm | (e) AI-tells | (f) Close | Total /30 |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| the-psychology-of-money | 5 | 5 | 4 | 2 | 3 | 3 | **22** |
| sapiens | 5 | 3 | 4 | 4 | 3 | 2 | **21** |
| mans-search-for-meaning | 5 | 4 | 4 | 2 | 3 | 3 | **21** |
| never-split-the-difference | 5 | 3 | 3 | 4 | 3 | 3 | **21** |
| the-body-keeps-the-score | 4 | 3 | 4 | 3 | 3 | 3 | **20** |
| thinking-fast-and-slow | 4 | 2 | 3 | 3 | 4 | 3 | **19** |
| deep-work | 4 | 2 | 3 | 3 | 3 | 2 | **17** |
| atomic-habits | 4 | 2 | 3 | 2 | 3 | 2 | **16** |
| **Mean** | **4.5** | **3.0** | **3.5** | **2.9** | **3.1** | **2.6** | **19.6** |

Slightly harder than the prior pass (mean 19.6 vs 20.6). The two deltas are **(f) Close** (prior rewarded payoff-tails, but all 8 closes redirect to our product, so the book-motivation criterion is failed catalog-wide and is capped at 3) and **(d) Rhythm** (re-scored against the measured sentence-length distributions — see corrections).

---

## Per-book analysis

### the-psychology-of-money — 22/30 (catalog best)
- **(a) 5:** Opens on a true scene — *"In 2014, a Vermont gas-station attendant and janitor named Ronald Read died leaving more than six million dollars… the same decade plenty of Harvard-trained financiers went broke."* Concrete, counterintuitive, named.
- **(b) 5:** Ronald Read, $6M, Bill Gates, Kent Evans, Warren Buffett, Rajat Gupta, Bernie Madoff — six named people with specifics. The only summary that fully satisfies the concreteness effect.
- **(c) 4:** Carries the rubric's only explicit meta-caveat: *"as an account of what Housel claims, not advice."*
- **(d) 2 [CORRECTION — prior gave 3]:** Measured rhythm is a flatline of long sentences: every one of its 10 sentences runs 20–57 words; shortest is 20. No short sentence for impact anywhere. After the Ronald Read hook it never lets the reader breathe.
- **(e) 3:** Em-dash rate is the **worst in the catalog at 6.10/300** (7 em-dashes). Prior called this "slightly above the ideal" — **[CORRECTION]**, it is roughly double the threshold and the highest of all eight. Offsetting this: only 1 three-item list, no lexical clusters.
- **(f) 3:** *"…the stories of janitors, moguls, and glaciers that make them stick."* "Glaciers" is opaque to a non-reader, and the close still points to our full summary.
- **AI-tells quoted:** em-dash chain ("hospital — the same decade," "graduation — same school, same talent," "never stopped — so the first job," "not spent — assets accumulating," "these arguments — as an account"); vague attribution ("the strongest predictor of well-being in the research he cites" — name Deaton).
- **Benchmark does better:** Harriman House gives a portable aphorism — *"Doing well with money isn't necessarily about what you know. It's about how you behave."* Ours has the better hook (Read) but no carry-away line.
- **Edits:** (1) Break the long sentences — drop in one 4–6 word sentence after the Read hook. (2) Replace "glaciers" with a concrete close ("Warren Buffett's childhood savings account"). (3) Name the well-being study (Deaton).

### sapiens — 21/30
- **(a) 5:** Question hook — *"How did an unremarkable primate from East Africa end up running the planet?"*
- **(b) 3:** Strong concept nouns ("gods, nations, money, corporations"; the email/smartphone "luxury trap") but no proper-noun illustration (no Peugeot, no named figure).
- **(c) 4:** Genuine interpretation — *"he argues against the standard celebration"*; *"controversially counts liberalism and capitalism."*
- **(d) 4:** Best burstiness in the catalog — 13 sentences from 10 to 54 words.
- **(e) 3:** "controversially" hedge adverb; 4.79 em/300; meta-close tricolon.
- **(f) 2 [CORRECTION — prior gave 3]:** Pure table-of-contents recap: *"The full summary traces each revolution, the great unifiers, and the happiness ledger in depth."* Points at our product, lists three of its parts, adds nothing.
- **Benchmark does better:** ynharari.com quotes Harari verbatim — *"the only animal that can believe in things that exist purely in its own imagination."* Ours paraphrases ("believing shared stories"), losing precision.
- **Edits:** (1) Near-quote Harari in sentence two. (2) Replace the meta-close with the book's open question ("we have become gods without knowing what we want"). (3) Name one illustration (Peugeot).

### mans-search-for-meaning — 21/30
- **(a) 5:** Superb scene hook — Frankl *"arrived at Auschwitz carrying the manuscript of his life's work, and lost it within hours."*
- **(b) 4:** Real biographical anchor; missing one clinical scene (the bereaved widower from Part 2).
- **(c) 4:** Distinguishes avoidable from unavoidable suffering; names "tragic optimism."
- **(d) 2 [CORRECTION — prior gave 4]:** This is the **worst-measured rhythm in the catalog**: all 10 sentences run 25–50 words; the shortest is 25. There is no short sentence anywhere. The prose is elegant but metronomic-long — exactly the low-variance pattern `ai-tells.md §2.4` flags. Prior scored this 4; the distribution does not support it.
- **(e) 3:** Two inflated signposts — *"his most enduring claim"* and *"His most prophetic chapter"*; the invented *"three doors"* metaphor (Frankl uses no door metaphor); meta-close.
- **(f) 3:** Close at least gestures at content the summary omits ("the clinical encounters"), but still routes to our full summary.
- **Benchmark does better:** Beacon Press leads with the Nietzsche epigraph — *"He who has a why to live can bear almost any how"* — borrowing the book's gravity in nine words.
- **Edits:** (1) Insert at least one short sentence (e.g. after the manuscript loss: "He never got it back."). (2) Replace "three doors" with Frankl's actual framing. (3) Cut "most enduring"/"most prophetic" superlatives; state the claims directly.

### never-split-the-difference — 21/30
- **(a) 5:** *"After two decades talking kidnappers and bank robbers out of killing people…"* — credentials as scene, then the thesis ("business-school negotiation rests on a fantasy").
- **(b) 3:** Techniques named and defined (tactical empathy, mirroring, labeling, accusation audit, black swans) but **no case scene** — the 2006 Brooklyn bank robbery and Haiti kidnapping are absent.
- **(c) 3:** Reports Voss's claims confidently; no stated limit (where does the method *not* transfer?).
- **(d) 4:** Good variety — 6 to 56 words.
- **(e) 3:** "deceptively simple" cliché; the manufactured-symmetry aphorism *"people who feel heard open up while people who feel processed dig in"* (`ai-tells §2.8`); meta-close.
- **(f) 3:** *"…the hostage standoffs, salary talks, and car-lot haggles that turn the tips into instincts"* — gestures at the book's stories but inside the meta-close formula.
- **Benchmark does better:** Black Swan Group opens with a four-part frontal assault ("you are not rational; there is no such thing as 'fair'; compromise is the worst thing you can do…").
- **Edits:** (1) Add the Brooklyn bank-robbery scene. (2) Add one limit sentence (method forged with institutional leverage; weaker with no walk-away). (3) Cut "deceptively simple."

### the-body-keeps-the-score — 20/30
- **(a) 4:** Strong declarative thesis — *"Trauma is not rare, and it does not stay in the past."*
- **(b) 3:** Names van der Kolk, the ACE (adverse childhood experiences) study with its dose-response pattern, imaging findings, EMDR/yoga/neurofeedback/theater. But **missing the four prevalence statistics** that make the benchmark land.
- **(c) 4:** The catalog's strongest friction — *"no technique is a cure-all, that the evidence base varies… belongs with trained, trauma-informed professionals"* and *"This gist is a map of the book's ideas, not guidance."*
- **(d) 3:** Has an 8-word sentence; otherwise long.
- **(e) 3:** "The book's most far-reaching material" signpost; four 3+-item lists; meta-close.
- **(f) 3:** Names the omission honestly ("the debates around the book") but "the debates" is unspecified, and the close routes to our summary.
- **Benchmark does better:** PRH opens with the litany — *"one in five Americans has been molested; one in four grew up with alcoholics; one in three couples have engaged in physical violence."* Ours asserts what the benchmark proves.
- **Edits:** (1) Insert the prevalence statistics into the opener. (2) Name the specific controversy (e.g. repressed-memory debate) instead of "the debates." (3) Cut "the book's most far-reaching material" signpost.

### thinking-fast-and-slow — 19/30
- **(a) 4:** Question hook — *"Why do intelligent people make predictable mistakes?"*
- **(b) 2:** Amos Tversky and the Nobel named, loss aversion's "roughly twice as much" is a real number — but **no signature scene**: no Israeli judges, no Linda problem. "Mental fatigue and even hunger make people more impulsive" paraphrases the judges/glucose study without the scene or the figures.
- **(c) 3:** Faithful exposition, but **the replication crisis around priming — flagged in the Wikipedia benchmark and conceded by Kahneman — is entirely absent.** Reads as unconditional endorsement.
- **(d) 3:** Two 7-word sentences against a long-sentence body; modest variety.
- **(e) 4 [CORRECTION — prior gave 3]:** This summary has **0 em-dashes** — the cleanest in the catalog on the catalog's most-cited punctuation tell. Prior's claim that em-dash over-density "appears in all 8" is false; TFS is the counterexample. It still carries "his crucial claim" / "the famous distortions" signposts and the meta-close, hence 4 not 5.
- **(f) 3:** The "recognize the machinery of your own thinking while it runs" tail is good, but the sentence is still "The full summary works through each idea…".
- **Benchmark does better:** PRH's reflexive payoff — *"It will change the way you think about thinking."*
- **Edits:** (1) Insert the Israeli-judges scene with figures (≈65% parole early vs near 0% before lunch). (2) Add one sentence of replication friction. (3) Tighten the close to the book's most counterintuitive implication.

### deep-work — 17/30 (2nd-worst)
- **(a) 4:** *"Cal Newport's argument fits in a sentence"* — then takes a long one, but the thesis (focus is rare and valuable) lands.
- **(b) 2:** **No named case studies** — no Jung's tower, no Adam Grant's batching, no Rowling. The four philosophies are named (monastic/bimodal/rhythmic/journalistic) but nobody embodies them.
- **(c) 3:** "Newport contends / inverts" interpretive verbs, but no limit or for-whom.
- **(d) 3:** Has an 8-word sentence; range 8–58. Variety is fine; the problem is structural, not rhythmic.
- **(e) 3:** Em-dash density is actually **fine at 2.65/300** (3 dashes) — **[CORRECTION]**: deep-work is not an em-dash offender. Its real tell is **listicle-in-prose** (`§2.7`): the third paragraph is four imperatives with the bullets removed ("Adopt tools only when… plan every minute… negotiate an explicit budget… and become harder to reach"), plus an em-dashed four-item list ("monastic, bimodal, rhythmic, or journalistic"). Six 3+-item lists, the joint-highest. Plus the meta-close.
- **(f) 2:** Pure recap — *"lays out all four philosophies, the execution framework, and Newport's tactics for quitting the shallow on purpose."*
- **Benchmark does better:** calnewport.com defines the concept in one precise sentence; ours takes three.
- **Edits below (worst-2 rewrite).**

### atomic-habits — 16/30 (worst; highest-traffic book)
- **(a) 4:** Good thesis hook — *"James Clear's wager is that you don't need more willpower or a grander goal — you need a better system."*
- **(b) 2:** **No named example from the book** — no Dave Brailsford / British Cycling marginal-gains case (Clear's anchor). "Write one paragraph and you have backed the claim that you are a writer" is the only concrete touch, and it's generic.
- **(c) 3:** "Clear is skeptical of raw discipline" is mild interpretation; no limit/for-whom.
- **(d) 2:** Long-sentence heavy (avg 32.3, no sentence under 15); little punch.
- **(e) 3:** Highest em-dash *count* (6) at 5.07/300 — **[CORRECTION]**: prior said "four em-dashes," the real count is six. Six 3+-item lists (incl. two four-item loops: "cue, craving, response, and reward"; "obvious… attractive… easy… satisfying"). "The book's most distinctive idea" signpost. Meta-close.
- **(f) 2:** Pure recap — *"works through all four laws, the identity mechanics, and Clear's thinking on plateaus, talent, and choosing the right field."*
- **Benchmark does better:** Penguin/Clear opens on the reader's frustration and reframes blame — *"If you're having trouble changing your habits, the problem isn't you. The problem is your system."*
- **Edits below (worst-2 rewrite).**

---

## Worst-2 surgical rewrites (before → after)

### atomic-habits — open with the anchor case; kill the meta-close

**Before (opener):**
> "James Clear's wager is that you don't need more willpower or a grander goal — you need a better system. Habits compound like investments: a one percent daily improvement is invisible in the moment but transforms a year…"

**After:**
> "When Dave Brailsford took over British Cycling, the team hadn't won the Tour de France in its 100-year history. He changed almost nothing dramatically. He changed hundreds of things by one percent — the bike seats, how riders washed their hands, the pillow they slept on at hotels. Five years later they dominated. That is James Clear's wager: you don't need more willpower or a bigger goal. You need a better system, because a one percent edge is invisible on any single day and decisive across a year."

*(Adds a named scene, a long-short rhythm break, and cuts an em-dash.)*

**Before (close):**
> "The full summary works through all four laws, the identity mechanics, and Clear's thinking on plateaus, talent, and choosing the right field in greater depth."

**After:**
> "Clear's sharpest point is that a habit is a vote. Every skipped workout is a vote for someone who doesn't train; every paragraph written is a vote for a writer. The book is about winning that election — one small ballot at a time."

*(Replaces the table-of-contents recap with the book's own implication; motivates the book, not our summary.)*

### deep-work — name a case; de-listicle paragraph three

**Before (opener, abstract):**
> "Cal Newport's argument fits in a sentence: the ability to concentrate without distraction on demanding tasks is becoming both rarer and more valuable…"

**After:**
> "Carl Jung built a stone tower with no electricity at Bollingen so he could think without interruption — and produced the work that founded analytical psychology. Cal Newport opens with scenes like this to make one argument: the ability to concentrate without distraction is getting rarer and more valuable at the same time. The few who keep it will win outsized rewards. Everyone else will skim."

**Before (paragraph 3, listicle-in-prose):**
> "Adopt tools only when their benefits to what actually matters substantially outweigh their attention costs, plan every minute of the workday in revisable blocks, negotiate an explicit budget for shallow work, and become harder to reach. The full summary lays out all four philosophies, the execution framework, and Newport's tactics for quitting the shallow on purpose."

**After:**
> "His most useful rule is subtraction: keep a tool only when its real benefit to the work you care about outweighs what it costs your attention. Most tools fail that test. The deeper claim is harder to swallow — boredom, not busyness, is the enemy. If you can't sit in a queue without reaching for your phone, you've already lost the capacity deep work depends on, and no schedule will give it back."

*(Removes the four-imperative list and the meta-close; ends on the book's most counterintuitive claim.)*

---

## Systematic weaknesses — ranked by (widespread × fixable)

This ranking drives `SKILL.md`. Top items are both near-universal and mechanically fixable.

### 1. The "The full summary…" meta-close — 8 of 8 — trivially fixable — **TOP PRIORITY**
Every summary ends with a sentence that points the reader at *our longer summary*, usually as a three-item table of contents ("traces each revolution, the great unifiers, and the happiness ledger"). This fails the trailer test (`engaging §P10`): a close should make the reader want the *book*, not our other product. It is the most consistent single artifact in the catalog and the easiest to fix — delete the formula, end on the book's most counterintuitive implication or its open question.
**[CORRECTION]** Prior pass scored this 6 of 8; it is 8 of 8.

### 2. Em-dash over-density — 6 of 8 above threshold — mechanical fix
Six summaries exceed `ai-tells.md`'s ~3/300 line: psychology-of-money **6.10**, atomic-habits **5.07**, sapiens 4.79, never-split 4.46, mans-search 4.40, body 4.04. Used uniformly to attach clarifying clauses, never for dramatic reversal.
**[CORRECTION]** Not "all 8": thinking-fast-and-slow has **0** and deep-work 2.65 (both fine). And the worst offender is psychology-of-money, which the prior called only "slightly above." Fix: convert two-thirds to commas/parentheses; reserve one dash per piece for a genuine break.

### 3. Tricolon / rule-of-three default — 8 of 8 present, heavy in 4 — fixable
Three-or-more-item lists appear in every summary; heaviest in atomic-habits, deep-work, and body (6 each), plus four-item loops ("cue, craving, response, and reward"). The single cleanest is psychology-of-money (1 list) — and it is the highest-scoring summary, which is not a coincidence.
**[CORRECTION]** Prior ranked this #1 and claimed "every paragraph ends in a three-item list." It is real and pervasive, but the meta-close is more uniform, and psychology-of-money shows the catalog can avoid it. Demoted to #3. Fix: convert half of all three-item lists to one-item-explained or asymmetric two-item.

### 4. Concreteness deficit — no named scene — worst in 3 of 8 — high-impact, harder
atomic-habits (no Brailsford), deep-work (no Jung/Grant), thinking-fast-and-slow (no Israeli judges/Linda) score 2/5: they describe *that* an argument is made without the scene that makes it stick. The correlation is direct — psychology-of-money names six people and tops the table. Harder to fix because it requires book knowledge, but the highest-leverage substance change. Fix: every summary must carry ≥1 named person/study/number from the book, in a scene.

### 5. Rhythm flatline — no short sentences — worst in 3 of 8 — fixable
mans-search and psychology-of-money have **no sentence under 20–25 words** (every sentence 25–50 and 20–57 respectively); atomic-habits has none under 15. `ai-tells §2.4` flags exactly this low-variance, no-burst pattern.
**[CORRECTION]** Prior scored mans-search 4 and psychology 3 on rhythm; the measured distributions make them the two *worst*. The strong-rhythm summaries (sapiens, never-split, body, deep-work, thinking-fast) each contain a sub-10-word sentence. Fix: plant at least one sentence under 8 words per ~200 words.

### 6. No authorial friction / POV — 5–6 of 8 — one-sentence fix
Only body-keeps-the-score (cure-all caveat) and psychology-of-money ("an account of what Housel claims, not advice") state a limit. The rest, especially thinking-fast-and-slow (no replication-crisis note), are unconditional advocacy. Fix: one sentence naming who the book serves, where the evidence strains, or what is contested.

### 7. Inflated-significance signposts — 4–5 of 8 — trivial fix
"The book's most distinctive idea" (atomic), "The book's most far-reaching material" (body), "his most enduring claim" + "His most prophetic chapter" (mans-search), "His crucial claim" (thinking-fast). `ai-tells §3.5`.
**[CORRECTION]** Prior counted this in 3 of 8; mans-search has two and thinking-fast adds "crucial," so it is 4–5. Fix: cut the superlative, state the claim directly.

## Verified most-common AI-tells, with real frequencies

| Rank | Tell | Affected | Verified frequency |
|:---:|---|:---:|---|
| 1 | Meta-close "The full summary…" pointing at our product | **8/8** | Universal; final sentence of every summary |
| 2 | Three-or-more-item lists | 8/8 present | 1–6 per summary; median 4.5; min 1 (psych), max 6 (atomic/deep-work/body) |
| 3 | Em-dash over-density (>3/300w) | 6/8 | Mean 4.0/300 across all 8; range 0 (TFS) to 6.10 (psych) |
| 4 | Abstract claims with no named scene | 3/8 worst, 7/8 partial | atomic, deep-work, TFS at 2/5 concreteness |
| 5 | Inflated "the book's most X" / "crucial claim" signpost | 4–5/8 | atomic, body, mans-search ×2, TFS |
| 6 | No friction / unconditional advocacy | 6/8 | Only body + psych carry a stated limit |
| 7 | Listicle-in-prose (imperatives with bullets removed) | 3/8 | deep-work (worst), atomic, never-split |
| 8 | Rhythm flatline (no sentence <20w) | 3/8 | mans-search, psychology-of-money, (atomic <15w) |
| 9 | Hedge adverb / cliché ("controversially", "deceptively simple") | 2/8 | sapiens, never-split |

Lexical tells from `ai-tells §1` (delve, tapestry, underscore, robust, etc.) are **largely absent** — the catalog's prose is clean at the word level. The tells here are structural (close formula, lists, rhythm) and substantive (concreteness, friction), not vocabulary. This is the most important framing for the skill: our writer is not producing "delve"-grade slop; it is producing fluent prose with a fixed *architecture*.

## Rewriting-priority ranking (most urgent first)

1. **atomic-habits — 16** — worst overall, highest-traffic book; no named case, listy, recap close, flat rhythm. Maximum impact per edit.
2. **deep-work — 17** — listicle paragraph, no named case study, recap close.
3. **thinking-fast-and-slow — 19** — no signature scene (Israeli judges/Linda), no replication friction. (Already clean on em-dashes.)
4. **the-body-keeps-the-score — 20** — add the four prevalence statistics; name the specific controversy.
5. **sapiens — 21** — near-quote Harari; replace recap close with the book's open question.
6. **mans-search-for-meaning — 21** — break the long-sentence flatline; replace "three doors"; cut superlatives.
7. **never-split-the-difference — 21** — add a hostage-negotiation scene; add a limit sentence.
8. **the-psychology-of-money — 22** — strongest; thin the em-dashes (worst rate), add short sentences, fix the "glaciers" close.

## 6-line synthesis (for the writing-skills file)

1. **Every close points at our own longer summary, not the book (8/8).** This is the most systematic defect and the easiest win: kill the "The full summary works through…" formula; end on the book's sharpest implication or open question.
2. **Structure, not vocabulary, is the tell.** Lexical slop ("delve," "tapestry") is absent; the fingerprints are the meta-close, three-item lists (median 4.5/summary), and em-dash chains (mean 4.0/300, peaking at 6.10).
3. **Concreteness predicts quality.** The one summary that names six real people (psychology-of-money) tops the table; the three that name no scene from the book (atomic, deep-work, thinking-fast) sit at the bottom. Mandate ≥1 named scene each.
4. **Rhythm is a flatline in the "literary" summaries.** Mans-search and psychology-of-money have no sentence under 20 words; require at least one sub-8-word sentence per 200 words.
5. **No friction = no voice.** Six of eight advocate unconditionally; one stated limit per summary (who it serves, where evidence strains, what's contested) is the cheapest credibility gain.
6. **Em-dashes are not universal and lexical tells are not the problem** — so the skill must target architecture (close, lists, sentence-length variance, named specifics, one caveat), not a banned-words list.

---

*Eval covers `summary_short` only; long `summary` fields not scored. Counts produced programmatically per field on 2026-06-15.*
