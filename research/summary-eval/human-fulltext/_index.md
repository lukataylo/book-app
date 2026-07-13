# Human-Written Mid-Book Summary Eval — Cross-Book Index

**Scope:** 4 books, 5–9 sources each, drawn from Wikipedia (CC BY-SA, quoted generously),
professional reviews, study guides, personal reading-notes blogs, and one academic review —
each source selected specifically because it engages **content from the middle of the book**,
not the opening hook or closing payoff.

**Purpose:** Benchmark dataset for the "does not forget the middle" eval (see
[`../mid-book-fidelity.md`](../mid-book-fidelity.md)). Complements [`../human/`](../human/),
which only ever captures openings — promotional blurbs structurally cannot engage a book's
middle, which is itself one of this index's findings (see book 3 below).

**Assembled:** July 2026

---

## Books Covered

| Slug | Book | Author | Type | Why chosen |
|---|---|---|---|---|
| sapiens | Sapiens: A Brief History of Humankind | Yuval Noah Harari | Nonfiction, 4 parts | Long multi-part argument; middle (agriculture, empires, money, religion) is where the famous opening thesis has to do sustained work |
| guns-germs-and-steel | Guns, Germs, and Steel | Jared Diamond | Nonfiction, 19 chapters / 4 parts | 13,000 years of history in dense regional case-study chapters — the canonical "everyone remembers the thesis, nobody remembers chapter 12" book |
| mans-search-for-meaning | Man's Search for Meaning | Viktor Frankl | Nonfiction, memoir + theory | Has a genuinely painful psychological middle (the camp routine) that promotional copy actively avoids, plus a technical Part 2 (logotherapy mechanics) |
| crime-and-punishment | Crime and Punishment | Fyodor Dostoevsky | Fiction, public domain | The one plot-driven example — a dropped subplot (Svidrigailov, the Marmeladovs, Porfiry's interrogations) is an unambiguous, checkable failure in a way a dropped nonfiction nuance isn't |

---

## Cross-Book Synthesis: What Human Writers Do Differently in the Middle

Distilled across all four books' individual synthesis sections (see each file's closing
section for the full per-book version):

1. **Callbacks to the opening thesis are compressed to a single clause, never re-argued.**
   (sapiens) Padding the middle with a restated thesis is itself a tell; the human pattern is
   a minimal hand-off clause that trusts the reader to remember.
2. **Structure mirrors the source's own divisions.** (sapiens, guns-germs-and-steel) Summaries
   that follow the book's own chapter/part boundaries and named taxonomies end up with
   proportionate middle coverage almost as a side effect; summaries that reorganize by theme
   are the ones that quietly drop regional/sequential material.
3. **The middle reads cooler and denser, not more enthusiastic.** (sapiens) Rhetorical
   superlatives are bookended at the opening and close; the middle carries names, dates,
   numbers, and causal chains instead.
4. **Causal function is stated adjacent to the event, not deferred.** (crime-and-punishment,
   guns-germs-and-steel) Human summaries don't just report that something happened in the
   middle — they say why it mattered right there, in the same sentence or the next one.
5. **Open loops are tolerated across large spans.** (crime-and-punishment) A thread introduced
   in the middle and paid off much later stays open in a human summary; a chunk-bound
   summarizer tends to either resolve it too early or drop it once its source chunk scrolls
   out of context.
6. **Concrete objects/named entities serve as continuity anchors.** (crime-and-punishment) Their
   consistent reappearance (the same amount of money, the same object, the same name) is a
   cheap, checkable proxy for whether a summarizer tracked the middle at all.
7. **Genre/purpose gates whether the middle survives.** (mans-search-for-meaning) Promotional
   material skips the middle entirely because it isn't persuasive; comprehension-oriented
   sources (study guides, reviews, personal notes) keep it. A generator prompted with
   marketing-flavored instructions will structurally reproduce this bias.
8. **Extended arcs get converted into an explicit, numbered taxonomy — a faithful compression.**
   (mans-search-for-meaning) "Three phases," not one flattening sentence.
9. **Exactly one scene from the middle gets promoted to full narrative treatment**, rather than
   trying to cover the middle proportionally-but-thinly. (mans-search-for-meaning)
10. **The middle gets paraphrased; the bookends get quoted.** (mans-search-for-meaning) Human
    writers treat the opening/closing as fixed, citable artifacts and the middle as something
    to digest and interpret in their own words — the inverse of what a lazy summarizer does
    (verbatim-adjacent opening/closing, vague gestures at "the middle chapters").

These ten observations are the basis for the generator prose rules in
[`../mid-book-fidelity.md`](../mid-book-fidelity.md) §3.

---

## Format note

Individual files intentionally avoid re-quoting material already captured in `../human/` for
the same book (openings, famous pull-quotes) — cross-reference that directory for the
short-blurb/opening-hook benchmark. Per-source excerpts here are kept to short (1–3 sentence),
fully attributed quotes for anything copyrighted; Wikipedia content is quoted more generously
under its CC BY-SA license. See each file's own legal note for source-by-source detail.
