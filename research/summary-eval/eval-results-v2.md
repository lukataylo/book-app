# Summary Writing-Quality Eval — Re-Run (v2)

**Date:** 13 July 2026
**Scope:** The same 8 shipped `summary_short` fields scored in `eval-results.md` (2026-06-15),
re-pulled fresh from `BookApp/Resources/SummaryPacks/<slug>.json` and re-scored against the same
rubric — plus a new pass checking [`claude-tells.md`](./claude-tells.md)'s additions, which didn't
exist at the time of the original eval.
**Supersedes:** `eval-results.md`. This is not a re-scoring of the same text with a stricter eye
(as `eval-results.md` was to its own predecessor) — **the shipped text has changed**. Every one of
the 8 summaries now reads as a substantially rewritten pass; several of the exact surgical edits
`eval-results.md` proposed verbatim now appear in the shipped copy (see per-book notes).

## Methodology

Same as `eval-results.md`: absolute rubric, not blinded; counts (words, em-dashes, sentence
lengths) produced programmatically per field; sub-scores 0–5 on (a) thesis-first hook,
(b) concreteness/named real examples, (c) authorial POV & stated limits, (d) voice &
sentence-rhythm variety, (e) freedom from AI-tells, (f) close that motivates reading the book.
Added this pass: a scan of every `claude-tells.md` §7 checklist item (extra vocab, extra phrases,
paragraph-cohesion pattern) alongside the existing `ai-tells.md` §5 scan.

## Verified measurements (re-counted, current shipped text)

| Book | Words | Em-dashes | Em/300w | 3+ item lists | Sentences | Avg len | Shortest sent |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| atomic-habits | 325 | **0** | 0.00 | 3* | 21 | 15.5 | **3** |
| sapiens | 361 | 2 | 1.66 | 4* | 17 | 21.2 | 5 |
| thinking-fast-and-slow | 403 | 1 | 0.74 | 2* | 16 | 25.2 | 6 |
| the-psychology-of-money | 365 | 4 | **3.29** | 0 | 17 | 21.5 | **3** |
| mans-search-for-meaning | 321 | **0** | 0.00 | 3* | 18 | 17.8 | **4** |
| deep-work | 341 | 1 | 0.88 | 4* | 18 | 18.9 | 5 |
| the-body-keeps-the-score | 331 | 1 | 0.91 | 4* | 15 | 22.1 | 7 |
| never-split-the-difference | 368 | **0** | 0.00 | 6* | 15 | 24.5 | 6 |

*3+ item lists here are mostly the books' own real taxonomies (Clear's cue/craving/response/reward,
Newport's monastic/bimodal/rhythmic/journalistic, Voss's named techniques) rather than filler
tricolons — see per-book notes; the raw count alone overstates the issue for this pass.

**Meta-close "The full summary…" formula: 0 of 8 (was 8 of 8).** Every summary that ended by
pointing at our own longer summary now ends on the book's own implication instead. This was
`eval-results.md`'s #1-ranked, "top priority" systematic defect. It is gone, catalog-wide.

**Sub-8-word sentence present: 8 of 8 (was 5 of 8).** Every summary now has at least one sentence
under 8 words — including the two previous worst offenders on rhythm, `mans-search-for-meaning`
("He never recovered it.") and `the-psychology-of-money` ("He never stops.").

## Scored table

| Book | (a) Hook | (b) Concrete | (c) POV | (d) Rhythm | (e) AI-tells | (f) Close | Total /30 | Δ vs. v1 |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| atomic-habits | 5 | 5 | 5 | 5 | 5 | 5 | **30** | **+14** |
| deep-work | 5 | 3 | 5 | 5 | 4 | 5 | **27** | **+10** |
| mans-search-for-meaning | 5 | 4 | 4 | 5 | 5 | 4 | **27** | +6 |
| thinking-fast-and-slow | 4 | 4 | 5 | 4 | 4 | 5 | **26** | +7 |
| never-split-the-difference | 5 | 3 | 5 | 4 | 4 | 5 | **26** | +5 |
| sapiens | 5 | 3 | 5 | 4 | 4 | 5 | **26** | +5 |
| the-body-keeps-the-score | 4 | 3 | 5 | 4 | 5 | 4 | **25** | +5 |
| the-psychology-of-money | 4 | 4 | 3 | 5 | 4 | 5 | **25** | +3 |
| **Mean** | **4.6** | **3.6** | **4.6** | **4.5** | **4.4** | **4.75** | **26.5** | **+6.9** |

Every book improved. The catalog mean rose from 19.6/30 to 26.5/30. The two biggest movers
(atomic-habits +14, deep-work +10) were exactly the two `eval-results.md` flagged as "worst-2" and
supplied verbatim surgical rewrites for — and the shipped text now matches those rewrites almost
line for line (see below).

---

## Per-book notes (what changed, what's still open)

### atomic-habits — 30/30 (was 16, biggest mover)
The shipped opener and closer are near-identical to `eval-results.md`'s proposed rewrite: it now
opens "You do not rise to your goals; you fall to your systems," uses an **original** compounding
example (1% of a paycheck, not Clear's own Brailsford/British-Cycling anecdote — correctly
following SKILL.md Rule 2's legal-safety constraint rather than reinstating the book's own case),
carries a real stated limit ("it says less about which goals are worth chasing in the first
place"), and closes on the book's implication ("You are the sum of the small votes you cast on an
ordinary Tuesday") instead of a table-of-contents recap. Nothing left to flag.

### deep-work — 27/30 (was 17, second-biggest mover)
Matches the proposed rewrite closely: opens on the thesis directly, uses an original illustration
(the line cook) rather than Newport's own Jung/Grant examples, states an explicit limit ("fits
knowledge workers far better than... jobs defined by responsiveness or care"), and the listicle-
in-prose paragraph from v1 is gone. **Still open:** concreteness (3/5) is the one sub-score that
didn't fully recover — the line-cook image is vivid but still a single invented instance, not a
named scene. This is now the catalog's joint-weakest concreteness score alongside
never-split-the-difference and sapiens, and it's the direct cost of Rule 2's legal constraint
(can't use the book's own examples) — the harder problem is inventing an *equally* vivid original
scene, not just an original abstraction.

### mans-search-for-meaning — 27/30 (was 21)
The exact short-sentence fix landed: "It was confiscated within hours. He never recovered it."
The invented "three doors" metaphor and the "most enduring claim"/"most prophetic chapter"
superlatives are both gone. **Still open:** no clinical mid-book scene (the bereaved-widower
example flagged in v1) — concreteness stays at 4, not 5, on that basis alone.

### thinking-fast-and-slow — 26/30 (was 19)
The Israeli-judges scene is now present in substance ("Picture an official grinding through a
long docket of rulings... the easy, status-quo decision grows steadily more tempting") though
without the actual national detail or the 65%/near-0% figures — a scene without its specifics.
The replication-crisis friction landed word for word as recommended ("several of the
social-priming studies it cites have since replicated poorly, and Kahneman himself publicly
conceded"). **Still open:** naming the judges' nationality and the actual percentages would move
concreteness from 4 to 5.

### the-psychology-of-money — 25/30 (was 22, smallest mover — it was already the catalog's best)
Notably, this rewrite **removed** the Ronald Read/$6M detail that v1's eval called "the only
summary that fully satisfies the concreteness effect" — replaced with an anonymized "quiet
schoolteacher." This looks like a deliberate SKILL.md Rule 2 correction: Ronald Read is Housel's
own signature anecdote, not an original illustration, so the prior version was actually the
catalog's highest legal-risk text despite scoring best on concreteness. The new version invents
its own two-teenagers luck/risk example instead. Concreteness score is essentially unchanged (4)
but for a different, legally safer reason. **Still open:** em-dash rate (3.29/300) is the *only*
remaining em-dash overage in the whole catalog — down from 6.10 (the worst in v1) but not fully
under the ~3/300 line yet. No stated friction/limit sentence either (3/5 on POV) — the one
sub-score untouched since v1.

### the-body-keeps-the-score — 25/30 (was 20)
The specific controversy is now named ("the support for EMDR and the recovered-memory debates
still genuinely contested") instead of v1's vague "the debates around the book." **Still open:**
the PRH benchmark's prevalence-statistic litany ("one in five... one in four... one in three")
that v1 recommended inserting is still absent — concreteness stays at 3.

### sapiens — 26/30 (was 21)
Close now lands on the book's own open question ("wields god-like powers to redesign life itself,
without any settled idea of what to want") instead of the v1 table-of-contents recap, and picks up
a genuine friction line ("Historians quarrel with plenty of his details, and the quarrel is part
of the point"). **Still open:** still no named proper-noun illustration (no Peugeot, no historical
figure) — the corporation example is a strong concept but not a concrete instance, so concreteness
holds at 3.

### never-split-the-difference — 26/30 (was 21)
The stated-limit close landed almost verbatim as proposed ("The system was forged where Voss could
not walk away, which gave him institutional weight that most salary talks... simply lack").
**Still open, and the catalog's one surviving instance of a named `ai-tells.md` pattern:** the
symmetrical-balance sentence flagged in v1 — "people who feel heard open up while people who feel
processed dig in" (`ai-tells.md` §2.8, manufactured grammatical symmetry) — is still present
verbatim. No case scene (Brooklyn bank robbery) was added either; concreteness holds at 3.

---

## `claude-tells.md` cross-check (new in this pass)

Ran every §7 checklist item from `claude-tells.md` against all 8 texts:

- Extra vocabulary (`dive into`, `bolster`, `unpack`, `shed light on`, `pave the way`,
  `cutting-edge`, `game-changing`, `multifaceted`, `holistic`): **0 hits across all 8.**
- Extra phrases (`when it comes to`, `this is where X comes in`, `plays a crucial role in`):
  **0 hits.**
- Validation-opener tic ("You're absolutely right that..."): not applicable — these are prose
  summaries, not chat/agentic turns; the tic is specific to conversational contexts per
  `claude-tells.md` §7.
- Paragraph-cohesion pattern (few, long, "mini-essay" paragraphs): present by design (each
  `summary_short` is 3–4 paragraphs of substantial, multi-idea prose) but this is the intended
  shape for this format, not a defect — `claude-tells.md` is explicit that this pattern isn't
  itself disqualifying.
- One keyword match worth noting as a **false positive**: `never-split-the-difference` contains
  "leverage" ("finds leverage nobody knew existed") — this is the literal, non-metaphorical sense
  (negotiating power), not the `ai-tells.md` §1.1 filler usage ("leverage your strengths"). Not a
  tell.

**Net finding: the claude-tells.md pass surfaces zero new issues beyond what ai-tells.md already
caught.** This corroborates `claude-tells.md`'s own honest conclusion (§6) that most claimed
Claude-specific tells are either already covered by the generic list or unverified — there is no
hidden Claude-only failure mode this catalog is running into that the original rubric missed.

---

## What's left (ranked, for the next pass)

1. **Concreteness is now the single weakest sub-score catalog-wide (mean 3.6/5, vs. 4.4–4.75 on
   every other criterion)** — and it's structurally the hardest one to fix, because SKILL.md
   Rule 2 forbids using the books' own signature anecdotes for legal safety. The books still
   scoring 3 (deep-work, sapiens, never-split-the-difference) need an *original* scene as vivid
   as the ones the rule disallows, not just an original abstraction. This is real writing work,
   not a mechanical fix like the em-dash/meta-close items were.
2. **the-psychology-of-money's em-dash rate (3.29/300)** is the one remaining mechanical overage
   in the catalog — thin two of the four dashes to commas/parentheses.
3. **never-split-the-difference's symmetrical-balance sentence** ("people who feel heard...
   people who feel processed...") is the catalog's one surviving named `ai-tells.md` pattern —
   restate the relationship instead of building the parallel clause.
4. No further action needed on: meta-close (fully fixed, 0/8), sub-8-word rhythm variety (fully
   fixed, 8/8), lexical/vocabulary tells (clean, including the new claude-tells.md vocabulary),
   or inflated-significance signposting (not found in any of the 8 on this pass).

---

*Eval covers `summary_short` only, matching `eval-results.md`'s scope; long `summary` fields not
re-scored. Counts produced programmatically per field on 2026-07-13.*
