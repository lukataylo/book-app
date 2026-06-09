# Read · Remember · Act — the summary-first redesign

*Shipped 2026-06 · implements the direction explored in `research/pivot-2026/PLAN.md`*

## Why

The pre-redesign app was a **tool you bring content to**: import an EPUB/PDF, then
compress, restyle, listen, speed-read. Strong tech, but the user interviews behind
`research/pivot-2026` pointed at a different job: *"help me learn the big ideas from
the best books in the time I have — and actually keep and use them."* That's the
Blinkist/Headway job (summaries), plus the Deepstash job (snackable idea cards),
plus a job none of them finish: turning a book into something you *do*.

## Deep review of what was here

What carried over cleanly, and why the redesign was cheap:

| Existing piece | Role in the redesign |
|---|---|
| `Book` + `BookVariant` + the reader/TTS/speed-read stack | A summary is just a book whose `.original` variant *is* our summary text — every reading feature works on catalog titles unchanged |
| `KeyLearning` + Annotations + Bookmarks gallery | Kept verbatim; now lives under the **Saved** tab alongside saved cards |
| `LLMRouter` (Foundation Models → Claude fallback) | Powers on-demand card decks and action plans for *any* book, including user imports |
| `SeedBooksLoader` pattern | Mirrored by `SummaryPackLoader` for the new catalog |
| Elastic-length transformations | The "resize any summary to your depth" differentiator from the pivot plan |

What was missing: a content catalog, a memorisation surface, and any bridge from
reading to doing.

## The new information architecture

Five tabs. The first three are the product loop; their names are the pitch:

1. **Read** — the existing library/home, now summary-first. Ships with a catalog of
   original "The Big Ideas in …" summaries (8 popular non-fiction titles at launch).
   Search moved from its own tab into the Read toolbar; import is unchanged.
2. **Remember** — Deepstash-style knowledge cards. Every catalog title ships with a
   curated 10–12 card deck (`KnowledgeCard`); any other book with text can generate
   one via `KnowledgeCardEngine`. Cards are full-bleed, gradient-coded by category
   (Principle / Mental Model / Habit / Insight / Warning / Practice), swipeable,
   shareable, and saveable.
3. **Saved** — everything kept, in one place: saved cards, plus the pre-existing
   Learnings list and Highlights gallery as segments. (The old Bookmarks tab lives
   here, feature-complete.)
4. **Act** — every book becomes a 14-day implementation plan (`ActionItem`).
   Catalog titles ship curated plans; `ActionPlanEngine` generates plans for
   anything else. Steps are checkable in-app, and `PlannerService` exports them to
   the system **Calendar** (timed practice sessions, write-only access) and
   **Reminders** (one-off to-dos) so the plan meets the user where their day is.
5. **Settings** — unchanged.

Cross-links: `BookDetailView` now surfaces Remember and Act rows per book, and
summary editions show a read-time badge on the shelf plus a legal attribution
footer on the detail screen.

## Data model additions

- `KnowledgeCard` — book-linked card (`title`, `body`, `category`, `order`,
  `saved`/`savedAt`, `source` seed|generated).
- `ActionItem` — book-linked plan step (`kind` task|event, `dayOffset` 1–14,
  `durationMinutes`, `completed`, `exportedToSystem`, `scheduledAt`).
- `Book` — `isSummaryEdition`, `sourceAttribution`, `readMinutesEstimate`, plus
  cascade relationships to both new models. All CloudKit-safe (defaults +
  optional inverses), registered in both model containers.

## Design language

Clean, minimal, iOS-native. **No gradients anywhere.** The editorial
black-and-white palette (`Theme.Palette`) stays primary; elevated content sits
on **glass** — `Material` surfaces with a hairline stroke and soft shadow
(`glassCard()` in `Design/Glass.swift`): knowledge cards, deck tiles, saved
rows, the continue-reading card, the search field, badges, toasts and the
Transform CTA bar. Category identity is carried by a small tint + SF Symbol
chip (`CategoryChip`), never by colored backgrounds. Generated book spines are
flat category color. Haptics (`sensoryFeedback`) confirm saves and check-offs;
materials degrade automatically with Reduce Transparency.

## The legally-safe summary model

Implements §3 of the pivot plan; **route through IP counsel before public launch**:

- Every summary is **clean-room original prose** conveying ideas and frameworks —
  copyright protects expression, not ideas. No quotes, no light paraphrase, no
  chapter-by-chapter mirroring; sections carry our own names.
- **Distinct naming**: catalog titles are "The Big Ideas in <Title>" — nominative
  reference, not passing-off. No cover art mimicry (generated spine covers only).
- **Attribution as fact** on every title: "An original summary of the ideas in
  <Title> by <Author> (<year>). Not affiliated with or endorsed by the author or
  publisher. If these ideas resonate, buy the full book." The line is rendered as
  the summary's first paragraph and on the detail screen.
- **Not a market substitute**: ~1,500-word idea-level companions (≈15 min) that
  end by pointing readers at the full book.
- `SummaryPackTests` enforces the framing mechanically: naming convention,
  attribution contents, idea-level length bands, deck/plan validity.

## Content pipeline

`BookApp/Resources/SummaryPacks/<slug>.json` (folder reference, walked by
`SummaryPackLoader` at launch, per-slug idempotent so update-shipped packs load
for existing users). Each pack: catalog metadata, summary text, 8–10 key
learnings, a 10–12 card deck, and an 8–10 step 14-day plan.

Launch catalog: Atomic Habits · Deep Work · Mindset · Thinking, Fast and Slow ·
Sapiens · The Power of Habit · The 7 Habits of Highly Effective People ·
How to Win Friends and Influence People.

## Privacy

Unchanged ethos: personal data (saves, completions, plans) stays in
SwiftData + private CloudKit. Calendar access is **write-only**
(`NSCalendarsWriteOnlyAccessUsageDescription`) — the app never reads existing
events; Reminders access is requested only when exporting a plan.

## Not built yet (next phases per the pivot plan)

Spaced-repetition scheduling on saved cards (SRS fields + daily review queue),
streaks/learning tree, illustrated micro-lessons, and the credits economy for
on-demand transformations.
