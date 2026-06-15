# SKILL — Writing a great book summary

How to write (and review) the "Big Ideas in …" summaries so they read like a sharp
human editor wrote them, not a model. Distilled from a human-benchmark dataset
(`human/`), AI-writing-tell research (`ai-tells.md`), engagement research
(`engaging-summaries.md`), and an opus eval of our own shipped packs
(`eval-results.md`). Rules are ordered by leverage — the eval proved these are
the failures in our catalog.

## The 6 rules that matter most (eval-driven, mandatory)

1. **Never close by advertising our own longer summary.** 8/8 of our packs end with
   "The full summary works through X, Y, and Z in greater depth." Kill it. End on
   the book's sharpest implication, an unresolved tension, or the one question only
   the full book answers. A summary is a trailer for *the book*, not for us.
2. **Be concrete — but with OUR OWN examples, never the book's.** Concreteness predicts
   quality in the eval, so ground each big idea in a specific scene, number, or
   everyday case. **For legal safety (these are copyrighted books), do NOT retell the
   author's signature anecdotes, case studies, or chosen illustrations** — the
   selection/arrangement of examples is the riskiest thing to copy. Instead invent an
   original illustration of the same idea, or use a widely-known fact that isn't
   distinctive to the book. You MAY name the author, the title, and the book's concepts
   or coined terms (attributed). Example: for "small habits compound," do NOT use the
   book's British-Cycling story; use an original case ("save 1% more each payday and
   the gap is invisible by Friday, decisive by retirement"). Keep it accurate to the
   idea; never invent claims the book doesn't make.
3. **Break the rhythm flatline.** Vary sentence length hard: at least one sub-8-word
   sentence per ~200 words. A wall of uniform 20–30-word "literary" sentences is the
   quietest, strongest AI tell. Short. Then a long one that earns its length.
4. **Earn one friction sentence.** Say who the idea serves, where the evidence
   strains, or what's contested. 6/8 of ours are unconditional advocacy — the single
   sentence willing to push back is what most separates human from machine.
5. **Lead with the thesis, not the topic.** First two sentences state the book's core
   claim, ideally as a mild provocation. No throat-clearing, no "In today's world."
6. **Cap the fingerprints, don't chase a word-list.** Our tells are *architectural*,
   not lexical (no "delve"/"tapestry" problem). Specifically: ≤1 em-dash per ~300
   words (reserve it for one genuine reversal); don't default every paragraph to a
   tricolon (vary 1 / 2 / many / none); cut inflated signposts ("the book's most
   crucial claim", "it's worth noting").

## Structure (a flexible template, not a formula)

- **Hook (1–2 sentences):** the thesis as a provocation or a concrete problem.
- **Through-line:** one sentence naming the spine the rest hangs on.
- **3–5 idea sections:** each = one load-bearing idea + a named example/scene from the
  book + (where natural) what it means for the reader. Use your own section headings
  ("The mathematics of tiny gains"), never the book's chapter titles. Deliberately
  *omit* sub-arguments — momentum comes from leaving things out, not cataloguing.
- **Close:** land on the sharpest consequence or the open question. Optionally one
  honest line on why the full book is worth the hours the summary can't replace.

## Length tiers
- **Quick take (~3 min, `summary_short`):** the thesis + the 3 biggest ideas, one
  named example total, a punchy close. No section headings.
- **Standard / deep (`summary`):** full section structure, an example per idea, one
  friction sentence, a real close.

## Voice
- Have a point of view; interpret, don't just report ("X is true *for knowledge
  workers*; it strains for shift workers"). A neutral recap is a Wikipedia stub.
- Second person where it sharpens ("You don't rise to your goals; you fall to your
  systems"). Earn aphorisms — one memorable line that survives the rest being
  forgotten.
- Write against the curse of knowledge: smart reader, zero exposure to the book.

## Self-check scan (run before shipping any summary)
- [ ] Does it open on the thesis, not the topic?
- [ ] ≥1 concrete example — and is it OURS, not the book's own anecdote/case study?
- [ ] Is there a sub-8-word sentence? Real sentence-length variance?
- [ ] One friction / "for whom / where it strains" sentence?
- [ ] Em-dashes ≤ ~1 per 300 words; not every paragraph a tricolon?
- [ ] Close lands on the book's implication — NOT "the full summary covers…"?
- [ ] No invented facts; no quoting the source verbatim; original wording.

## Anti-patterns (auto-reject)
- "The full summary works through …" / any close that points at our product.
- Three idea-sections that name no person, place, study, or number.
- Every paragraph the same length and shape; balanced "It's not just X, it's Y".
- Unconditional advocacy with no stated limit.
- Chapter-by-chapter abridgement (reads as a substitute for the book; also raises IP risk).
- Retelling the author's signature anecdotes/examples/case studies (IP risk — use our own).
