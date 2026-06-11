# Pivot 2026: Summary-first, learning-first

*Research project · drafted 2026-06-03 · status: exploration*

*Companion research: see [`user-pain-points.md`](user-pain-points.md) for competitor user complaints and the openings they expose.*

---

## 1. The thesis

Your user interviews are pointing away from *"a better reader for books I already own"*
and toward *"help me actually learn and remember things from the world's best books,
in the time I have."*

That is a different product. Today's app is a tool you bring content to; the pivot
brings content to you (original, legally-safe summaries of major books)
and wraps it in a learning system. Users save insights, get quizzed on a
spaced-repetition cadence, and read snackable illustrated portrait micro-lessons
(Imprint-style). You generate the content, hand it to the user, and monetise on-demand
content transformation on top.

> **Old promise:** "Books that bend to your time."
> **New promise:** "Learn the big ideas from the best books, and actually remember them."

Three reference products define the corners of the space:

| Reference | What we take | What we change |
|---|---|---|
| **Blinkist / Headway** | Original short summaries of major non-fiction; catalog + categories | We let the user resize *any* summary to their depth, and turn it into memory |
| **Imprint** | Portrait, snackable, *illustrated* micro-lessons; beautiful daily habit | We generate this content per-book, on demand, from our own summaries |
| **Duolingo** | Streaks, a learning "tree," spaced-repetition review, gamified retention | The "course" is a book's key ideas, not a language |

---

## 2. What stays, what changes

### Carries over (this is why the pivot is cheap to build)

- **`BookVariant` compress/expand engine** → becomes the user's "upsize / downsize" of a
  summary. The same elastic-length tech, repointed at our summaries instead of the
  user's imported files. This is your moat for "enrich with their own resizing."
- **`KeyLearning` model** → becomes a Memory (a saved insight). Already has `starred`,
  `userEdited`, `tags`, `book` relation, `locator`. We extend it for spaced repetition.
- **LLM routing (Foundation Models + Claude)** → the content-transformation backend.
- **TTS / Listen mode / speed-read** → still valuable; every summary and micro-lesson is
  listenable. Audio is a strong retention and accessibility channel.
- **SwiftData + CloudKit, no-backend ethos** → *partially* changes (see §5: we now ship a
  catalog, which implies some server-side content delivery).

### New surfaces to build

1. **Catalog of original summaries:** browse/discover major books as legally-safe rewrites.
2. **Memories:** the saved-insight store plus spaced-repetition review engine.
3. **Learning tree:** a Duolingo-style progression over a book's key ideas (or a curated
   collection of books).
4. **Imprint-style micro-lessons:** portrait, illustrated, snackable cards generated from a
   summary; used both as first-time learning and as spaced reminders.

---

## 3. The "legally-safe summary" model  ⚠️ needs IP counsel sign-off

This is the highest-risk part of the pivot. I can give you a defensible *design*, but the
words "legally safe" should be earned with a lawyer, not asserted by us. The pragmatic frame:

**What copyright does and doesn't protect**
- Copyright protects an author's *expression*, **not** facts or ideas. You can lawfully convey
  the *ideas* in a book.
- Risk lives in three places: (a) reproducing distinctive *expression* (quotes, memorable
  phrasings, the unique selection/arrangement of an abridgement), (b) being a *market
  substitute* for the original (the 4th fair-use factor, the one courts weigh most), and
  (c) **trade dress / trademark** (covers, titles, series branding).

**Design rules that follow from that**
1. **Clean-room rewrite.** Every summary is original prose that conveys *ideas and frameworks*,
   never the book's sentences. No copy-paste, no light paraphrase. Generated, then editorially
   checked.
2. **High-level, not a chapter-by-chapter clone.** Transformative commentary and key takeaways,
   explicitly not a complete abridgement that replaces the purchase.
3. **Totally different covers & titling.** Original art, our own naming/subtitle convention
   (e.g. *"The big ideas in <Title>"* as nominative reference). No mimicking trade dress.
4. **Attribution as fact.** "Based on the ideas of <Author>, <Title> (<year>)." Nominative
   use of a title to say *what we summarise* is generally defensible; passing-off is not.
5. **No verbatim beyond minimal fair quotation**, clearly marked, sparing.
6. **Encourage the source.** A "Buy the book" link reduces the market-substitution argument
   and is good faith.
7. **Marquee titles → consider licensing.** For the 50 most-recognisable books, a license
   path de-risks the flagship catalog even if the long tail runs on clean-room summaries.

> **Action:** before any public launch, route the summary generation + presentation spec
> through IP counsel. Blinkist/Headway operate in this space at scale, which is encouraging,
> but it is contested ground, jurisdiction-dependent, and not a guarantee.

---

## 4. The four core experiences

### 4.1 Summaries (the catalog)
- ~10–15 min original read per book, ~8–12 key ideas, listenable.
- The user can downsize (1-min "gist") or upsize (deep ~30-min treatment) any summary
  on demand. This is the paid transformation hook (§6).

### 4.2 Memories (save + spaced repetition)
- Tap any insight → **Save as Memory**. Or **"Add whole book"** → seeds the deck with all key
  ideas at once.
- Each memory enters an SRS schedule (SM-2 / FSRS-style). The app surfaces due memories
  daily and lets the user grade recall (Again / Hard / Good / Easy), which reschedules.
- Memories can be plain insights, cloze/quiz cards, or illustrated micro-lessons.
- Reminders via local notifications + the existing widget ("today's memory").

### 4.3 Learning tree (Duolingo-style)
- A **course** = a book (units = themes, lessons = key ideas) **or** a curated **collection**
  (e.g. "Foundations of behavioural economics" spanning 5 books).
- Progression: complete a lesson → unlock the next → periodic checkpoint quizzes (boss
  nodes) that pull from spaced-repetition memory.
- Streaks, XP, daily goal, but the success metric is retention, not "books finished."

### 4.4 Imprint-style micro-lessons
- Portrait, full-bleed, illustrated, snackable (5–20 cards). Swipe-up feed mechanic.
- Generated *from* a summary on demand. Doubles as (a) first-time learning and (b) a
  spaced-repetition *reminder* that's pleasant rather than a dry flashcard.
- This is the most production-heavy piece (illustration). Options: generated illustration with
  a tight house style, a fixed icon/illustration system, or a hybrid.

---

## 5. Architecture implications

The biggest shift is that you now ship content, so the pure "no backend" stance softens.

- **Content delivery.** A catalog of summaries + cover art + (optionally) pre-rendered
  micro-lessons must be hosted and synced. Options, cheapest → richest:
  1. **Bundled/CDN JSON pack** pulled on launch (simple, cacheable, cheap).
  2. **Lightweight content API** (catalog, search, entitlements, generation jobs).
  3. Full backend with a generation pipeline + moderation/editorial queue.
- **Generation pipeline (offline, ours).** Per book: ingest → clean-room summary draft →
  key-ideas extraction → cover-art generation → micro-lesson cards → editorial QA → publish.
  This is a content-ops function, not just code.
- **On-device stays for personalisation.** Keep the user's resizes, memories, SRS schedule,
  streaks, and notes in SwiftData + private CloudKit (privacy story intact).
- **Data model additions** (sketch):
  - `Summary` (catalog item: title, author, our-cover ref, body variants, keyIdeas[], length tiers, legalStatus).
  - extend `KeyLearning` → `Memory`: add `srsEase`, `srsIntervalDays`, `dueAt`, `lastGrade`, `repetitions`, `lapses`, `cardKind`.
  - `Course` / `TreeNode` / `NodeProgress` for the learning tree.
  - `MicroLesson` (cards[], illustration refs, sourceSummaryID).
  - `ReviewSession`, `StreakState`, entitlement/credits records.

---

## 6. Business model

**Free / subscription / consumable, layered:**

- **Free:** browse catalog, a few full summaries, basic memories + daily review, limited tree.
- **Subscription (Plus):** unlimited summaries, unlimited memories, full tree, daily reminders,
  audio, the widget.
- **On-demand transformation (the differentiator, monetised as credits or à-la-carte):**
  - **Upsize / downsize** a summary to a custom depth.
  - **Generate an illustrated micro-lesson** from a summary.
  - **Restyle** ("explain it like Gladwell," "for a 12-year-old," "remove the religion theme").
  - **Build a custom tree** from a personal goal ("I want to get better at negotiation").
  - Each consumes credits (covers your LLM + illustration cost, with margin). Plus includes a
    monthly credit allotment; power users buy more.

Why this works: the catalog drives acquisition and habit (cheap to consume), while the
transformation (your genuinely differentiated tech) is where the marginal cost lives, so it's
the right thing to meter.

---

## 7. Risks & open questions

| Risk | Mitigation |
|---|---|
| **Legal:** summaries as derivative works / market substitution | Clean-room rules §3 + counsel sign-off + license marquee titles + "buy the book" |
| **Content cost & quality:** illustration + editorial at catalog scale | Tight house illustration style; start with a curated 100-book launch set, not 5,000 |
| **Generation economics:** transformation LLM/illustration cost vs. price | Credit model §6; cache common resizes; cheap tier on Foundation Models |
| **Habit retention:** the hard part of Duolingo-likes | Notifications + widget + streaks; review must feel like Imprint, not Anki |
| **Backend creep** vs. the privacy/no-backend brand | Keep *personal* data on-device/CloudKit; only *catalog* is served |

**Open questions for you:**
1. Catalog scope at launch: 50? 100? 500 titles? Which categories first?
2. Do we pursue licensing for flagship titles, or run fully clean-room?
3. Illustration: AI-generated house style, fixed icon system, or commissioned?
4. Pricing shape: is transformation *credits* or *à la carte*, and what's in Plus?
   > **Resolved (2026-06-11):** lead with honest billing as a positioning wedge.
   > Show transparent pricing *before* any quiz or email gate. Use a single
   > consistent price unit (no "$3/week" headline against an $80 charge). Keep a
   > visible in-app cancel button and trial-end reminders that actually fire.
   > Incumbents sit at ~1.9 on Trustpilot largely because of billing, so being
   > straightforward here is a cheap, durable advantage. The credits-vs-à-la-carte
   > split (§6) stays open, but whichever we pick must be priced in plain terms up front.
5. Platform: stay iOS-first, or is this finally the case for a backend + web?
6. Streak / habit shape: do we lean into Duolingo-style streaks, or build the
   habit loop differently to avoid the burnout the research flags?
   > **Resolved (2026-06-11):** go anti-burnout. Retention is measured by recall
   > performance, not streak length. Daily review load is capped. Catch-up is
   > forgiving, so a missed day never doubles the backlog into an avalanche. No
   > guilt-trip notifications, and the streak nudges rather than punishes.
   > Breaking a streak predicts total abandonment, and Anki's backlog avalanche is
   > the #1 quit trigger, so the punishment loop is what we most need to avoid.

---

## 8. Designing against incumbent pain

The companion research ([`user-pain-points.md`](user-pain-points.md)) found five
complaints that recur across Blinkist, Headway, Imprint, Shortform and the rest,
plus a secondary streak-burnout pain. Each one becomes a design rule we can check
at build time.

| Incumbent pain | Our design rule |
|---|---|
| **1. Billing dark patterns** (trial-to-lump-sum bait, quiz auto-enroll, broken cancel) | Transparent price shown before any quiz or email gate; one consistent price unit (no "$3/week" against an $80 charge); a working in-app cancel button; a trial-end reminder that actually fires. |
| **2. Illusion of learning** (consumed content, can't explain it a week later) | Every summary feeds the recall system; "did you learn it" is answered by graded recall, not by a finished-reading checkmark. We report retention, never "books completed." |
| **3. No active recall, or SRS burnout where it exists** | Save-as-Memory turns insights into active-recall cards on a forgiving FSRS schedule, with cloze and "explain it back" prompts. Daily load is capped and a missed day never doubles the backlog. |
| **4. Depth always wrong** (too thin or too bloated) | Elastic resize on every summary (the `BookVariant` engine): a 1-min gist or a ~30-min deep read of the *same* book, on demand, so the user sets depth instead of the catalog. |
| **5. AI-content distrust + robotic narration** | Clean-room editorial QA (§3) with stated "based on the ideas of…" attribution and a "buy the book" link; premium on-device system voices with word-range highlighting, not flat TTS. |
| **Secondary: streak / gamification burnout** | The streak nudges rather than punishes. No guilt-trip notifications, no congratulations the user can't turn off; the success metric is recall, not the counter. |

---

## 9. Suggested phasing

- **Phase 0, Validate (4–6 wks):** counsel review of §3; hand-make 10 summaries + 1 tree +
  micro-lessons; test retention and willingness-to-pay with interview cohort.
- **Phase 1, Summary-first MVP:** catalog (100 titles), full-summary reader, resize (reuse
  `BookVariant`), Save-as-Memory + daily review (extend `KeyLearning`).
- **Phase 2, Learning system:** the tree, checkpoint quizzes, streaks, notifications, widget.
- **Phase 3, Imprint layer:** illustrated micro-lessons + the on-demand generation/credits
  economy. Highest production cost, so it's last.

---

## 10. Wireframes

See `wireframes.html` in this folder. It holds three design directions, each covering the
three new screens you asked for (Home, Memories, Learning tree):

- **Direction A — Catalog-first** (Blinkist/Headway DNA): discovery feed leads; learning is a tab.
- **Direction B — Habit-first** (Duolingo DNA): the tree *is* the home; review queue is front and centre.
- **Direction C — Feed-first** (Imprint DNA): a vertical swipeable illustrated feed leads everything.

These are deliberately different information-architecture philosophies, not cosmetic skins.
Pick a corner (or a hybrid) before we refine to hi-fi.
