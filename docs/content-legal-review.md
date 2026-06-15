# Content / IP Risk Review

_Engineering/content risk assessment to scope a conversation with IP counsel. **Not legal advice** — fair use, trademark, and publicity calls are fact-specific legal judgments a lawyer must make._

## Overall posture: LOW–MEDIUM

The content is in noticeably better shape than the typical "book summary" app. Across 12 packs read in full + a verbatim-quote scan of all 80, the prose is **genuine original synthesis**: it paraphrases ideas in fresh wording, attributes coined terms descriptively ("what Voss calls tactical empathy"), and some packs add original critical commentary. Covers are **confirmed 100% original vector art** (grep for `<image>`/base64/`.jpg`/`.png` in the cover assets = nothing → no reproduced jackets). Residual risk is concentrated, not systemic.

## Findings by area

**1. Copyright / derivative work — LOW.** No verbatim quotation (a ≥3-word quoted-span scan of all 80 packs found only 4 benign hits). Coined/signature terms (System 1/2, WYSIATI, tactical empathy, black swans, logotherapy, deep work) used descriptively + attributed, not passed off. Structure is thematic re-org with the app's own headings, not the book's chapter sequence. Each pack closes with a "buy the full book" section → not a market substitute (helps fair use).
- _Closest to the line (still low):_ packs retell the **author's signature anecdotes** (selection the author created). `the-psychology-of-money` is the most example-dense and faithful to Housel's specific set pieces and order (Ronald Read, Gates/Kent Evans, Gupta, Madoff); `outliers` (Gates terminal, Beatles in Hamburg) and `mans-search-for-meaning` to a lesser degree. Facts/events aren't copyrightable, but "selection & arrangement of examples" is the theory a motivated plaintiff would test.

**2. Trademark / false endorsement — MEDIUM.** Titles to identify the book = classic nominative fair use, defensible. Raised to medium by: **author names rendered on every cover** (e.g. "James Clear," "Daniel Kahneman") — the author's *name* on a product cover edges toward implied endorsement (Lanham §43(a)) more than the title does. The title identifies the work (necessary); the name is more decorative/optional and is the first thing to consider trimming.

**3. Disclaimer — adequate wording, placement gap (LOW).** Strong strings exist (per-pack `attribution`; the `AcknowledgementsView` version asserts the paraphrase theory). Attribution is appended into the reading text + quick-take + TTS, and shown in `BookDetailView` footer. Gaps: in the reader it's only the **closing** paragraph (partial readers miss it), at low `caption2` prominence, and it does **not** appear on the cover or in catalog/list rows — the surfaces where titles+names are most prominent.

**4. Cover art — CLEAN, no issue.** Hand-authored vector SVG from a uniform house template with a bespoke per-book glyph; no embedded raster/jacket reproduction. Seed-classic `cover.jpg`s are standard Project Gutenberg templates (PD).

**5. Other:**
- _Public-domain classics — LOW, one check:_ confirm the **specific** bundled Gutenberg translations are PD (PG generally only hosts PD translations; one-line confirmation).
- _Transformation "style presets" — MEDIUM, the sharpest item:_ the Studio ships one-tap "rewrite in the style of" presets naming **living authors** (Gladwell, Harari, Tufte, Le Guin, …) and seed demos restyle "in the style of Yuval Noah Harari" / Gladwell (`TransformationStudioView.swift:60-65`, `SeedBooksLoader.swift:315,326`). Style isn't copyrightable, but productizing **named living authors** as presets invites right-of-publicity / false-endorsement arguments in a contested, fast-moving area of AI-imitation law.

## Prioritized mitigation checklist

**Do now (low effort):**
1. Surface a short "Independent summary · not affiliated" caption on book-detail header + catalog rows (not just the bottom footer).
2. Add a brief lead-in disclaimer to the reading text (in addition to the closing one).
3. Raise footer prominence above `caption2`; reuse the `AcknowledgementsView` wording as the canonical string.
4. Stand up a visible "Report a content / rights concern" contact + an internal per-title takedown process.

**Do soon (judgment calls — discuss with counsel first):**
5. Decide on **author names on covers** — lowest-risk: keep title, drop/de-emphasize the name.
6. Re-work transformation **style presets** to descriptive labels ("spare and literary," "data-driven explainer") instead of named living authors; review the shipped `restyled-harari`/`restyled-gladwell` seed demos.
7. Review the most example-faithful packs (`the-psychology-of-money`, `outliers`, `mans-search-for-meaning`) — swap in some original illustrations / generalize a couple of signature anecdotes.

**For counsel:** fair-use opinion on the paraphrase-summary model as executed; trademark/nominative-use on titles + author names + covers; right-of-publicity/false-endorsement on named-author style presets (sharpest, least-settled); confirm PD status of the specific Gutenberg translations; bless one canonical disclaimer string + required placements.

_What I can confirm (factual posture): no verbatim copying, no jacket reproduction, original art, disclaimers present and travelling into the reader, transformation operates on user content but ships named-author presets. Whether that posture **wins** on fair use / nominative use / publicity law is a legal judgment only counsel can give._
