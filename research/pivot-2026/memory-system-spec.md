# Memory system design spec

*Design spec · drafted 2026-06-11 · status: exploration · companion to [`PLAN.md`](PLAN.md) (§4.2, §4.4, §5) and [`user-pain-points.md`](user-pain-points.md)*

This spec covers the **Memories + spaced-repetition** learning system: the card kinds, the
scheduler, the data-model extension of the real `KeyLearning` type, and the retrieval flow from
summary to daily review. It is the build-out of `PLAN.md` §4.2.

> **Implementation status (2026-06-11): Phase 1 landed.** The model extension, scheduler, queue,
> store, and a review screen are in the app:
> - `BookApp/Models/KeyLearning.swift` (SRS fields + `CardKind`/`ReviewGrade`/`SuspendReason`)
> - `BookApp/Models/MemoryModels.swift` (`ReviewSession`, `ReviewLog`, `StreakState`)
> - `BookApp/Features/Memories/FSRSScheduler.swift` (pure scheduler, no-late-penalty rule)
> - `BookApp/Features/Memories/ReviewQueue.swift` (capped load, staggered seeding, catch-up metering)
> - `BookApp/Features/Memories/MemoryStore.swift` (SwiftData bridge: save / add-book / grade)
> - `BookApp/Features/Memories/MemoriesView.swift` (the daily review loop) + a "Memories" tab
> - Tests: `FSRSSchedulerTests`, `ReviewQueueTests`, `MemoryModelsTests`, and a teach-back prompt test.
>
> Insight and cloze/Q&A card kinds review today; teach-back grading (§2c, the prompt contract is in
> `PromptTemplates.teachBackGrading`) and illustrated micro-lessons (§2d) remain Phase 2–3.

---

## 1. Goal & the pain it solves

Summary apps create what `user-pain-points.md` §2 calls the illusion of learning: you finish a
summary, feel informed, and cannot explain the idea a week later (a 21-day Headway test had the
reviewer actively recall only 6 of 14 summaries). The category either ships no retention tooling
at all (Blinkist, Headway, getAbstract) or ships spaced repetition that burns people out
(Anki's backlog avalanche, §3). Nobody stitches summary → active recall → spaced review into one
flow. This system does, with anti-burnout scheduling so the recall layer itself does not become
the reason people quit.

---

## 2. Card kinds

A Memory is one saved idea plus a `cardKind` that controls how it is reviewed. All kinds share the
same scheduler (§3) and the same underlying record (§4). The difference is only in what is shown at
review time and how a grade is produced.

| Kind | Stores | How it's reviewed | Grade source |
|---|---|---|---|
| **Insight** | The idea text, source locator | Show the idea front, prompt "did you remember this?" | Self-grade (Again/Hard/Good/Easy) |
| **Cloze / quiz** | Prompt with a blanked span *or* a short Q&A, plus the answer | Show prompt with blank, user thinks/types, reveal answer | Self-grade against revealed answer |
| **Teach-back** | The source idea, a "explain in your own words" prompt | User types an explanation; LLM grades it vs. the source idea and returns feedback | LLM score mapped to a grade button |
| **Illustrated micro-lesson** | Card refs / illustration refs, `sourceSummaryID` | Portrait swipe-up cards (Imprint-style, `PLAN.md` §4.4), ends with a recall beat | Self-grade or embedded cloze |

### 2a. Insight
The default. Saving an insight from a summary creates this. Front is the idea, back is the same idea
plus its source context (book + locator). Pure recognition prompt: "Did this come back to you?" It
is the cheapest card to make and the floor of the system.

### 2b. Cloze / quiz
Turns an insight into retrieval. Two shapes share one kind:
- **Cloze:** a sentence with one span blanked (`clozeMask` marks the hidden range over `front`).
- **Short Q&A:** an explicit `front` question and `back` answer.

Generated from the insight text by the LLM at save time, or hand-authored. The user attempts recall
before revealing, then self-grades. This is the workhorse for `PLAN.md` §4.3 checkpoint quizzes.

### 2c. Teach-back / explain-in-your-own-words
The retention booster `user-pain-points.md` cites most (the Feynman/teach-back technique, §"what
users wish existed" #3). The user writes a free-text explanation of the idea. An LLM grades the
explanation against the source idea, returning a 0–100 `lastScore`, short feedback, and a
mapped grade button. The explanation and score are stored (`lastExplanation`, `lastScore`) so the
user can see their phrasing improve over reviews.

> **Grading prompt contract.** The judge gets the source idea + the user's explanation and returns
> `{score: 0-100, missedPoints: [String], feedback: String}`. Score → grade mapping:
> `<40 → Again`, `40–69 → Hard`, `70–89 → Good`, `≥90 → Easy`. Never punish phrasing or style,
> only whether the *idea* is present and correct. Feedback names what was missed, not what was wrong
> about the writing.

Routes through the existing LLM backend (Foundation Models for cheap on-device grading, Claude for
harder cases, `PLAN.md` §2). On-device first keeps cost and latency low for a daily-loop feature.

### 2d. Illustrated micro-lesson
The pleasant face of spaced repetition (`PLAN.md` §4.4): a short portrait, illustrated card deck
generated from a summary. Used both as first-time learning and as a *review* surface so a due
reminder feels like Imprint rather than a dry flashcard. The Memory stores refs to the rendered
cards and the `sourceSummaryID`; the last card carries a recall beat (an embedded cloze or a
self-grade) so a review still produces a grade. This is the most production-heavy kind and ships
last (§6).

---

## 3. Scheduling: FSRS with anti-burnout rules

The scheduler is **FSRS-style** (stability/difficulty per card, grade-driven interval growth). The
four grade buttons feed it:

| Button | Meaning | Effect |
|---|---|---|
| **Again** | Failed recall | Reset to a short relearning step; increment `lapses`; nudge difficulty up |
| **Hard** | Recalled with struggle | Smaller-than-default interval growth |
| **Good** | Recalled cleanly | Standard interval growth |
| **Easy** | Trivial | Larger interval jump; nudge difficulty down |

FSRS computes the next `srsIntervalDays` and `dueAt` from the prior interval, the card's stability,
and the grade. That part is standard. What matters for this product is everything below,
drawn from `user-pain-points.md` §3 and the §7 resolution in `PLAN.md`. Anki's backlog
avalanche is the #1 quit trigger: a missed day punished with a doubled backlog drives abandonment,
and we design around that.

### 3a. Capped daily review load
A hard cap on cards surfaced per day (default 20, user-adjustable). If more than the cap come due,
the rest stay due but are not shown today and are not counted as overdue debt. The user sees
"20 today" and a calm "more waiting" affordance, never "247 due."

### 3b. Forgiving catch-up (no avalanche)
When days are missed, overdue cards do not all pile into one session:
- Overdue cards are spread forward across upcoming days under the same daily cap, oldest-due
  first, instead of dumping into a single backlog.
- Intervals are not penalised for lateness. FSRS can optionally treat a late successful review
  as evidence of higher stability, but we never apply a punishment multiplier for the gap.
- A returning user after a long gap gets a "welcome back" reset: the queue is rebuilt at the
  daily cap, not as the sum of everything that came due while away.

> A missed day must never produce a session larger than the
> daily cap. If the math ever yields "do 200 today to catch up," the scheduler is wrong.

### 3c. Leech handling
A card that keeps failing is a leech (`lapses >= leechThreshold`, default 8). Anki users report
~15–20% of cards becoming dreaded leeches. On crossing the threshold:
1. **Auto-suspend** the card from the daily queue (`isSuspended = true`, `suspendedReason = .leech`).
2. **Offer to reformulate** it: send the idea + the failed attempts to the LLM to rewrite a clearer
   cloze or split it into two smaller cards. A reformulated card re-enters with `lapses` reset.
3. The user can also just retire it. A leech should leave the daily loop, not haunt it.

### 3d. Gentle reminders
Local notifications + the existing widget ("today's memory", `PLAN.md` §4.2). Rules:
- One nudge per day at the user's chosen time, never a guilt-trip. Copy is invitational
  ("3 memories ready"), never "you'll lose your streak."
- No congratulation spam (the Headway complaint, §"secondary"). Celebrations are quiet and dismissible.
- Reminders are off by default until the user opts in, and toggle independently from streaks.
- Streak, if shown at all, is a gentle nudge and never gates content. Retention is measured by
  recall performance, not streak length (`PLAN.md` §7 resolution).

---

## 4. Data model

### 4.1 Extending `KeyLearning` → Memory

The real `KeyLearning` (`BookApp/Models/KeyLearning.swift`) is the base. It already has everything a
saved insight needs; we add SRS state. We extend `KeyLearning` in place rather than forking a new
type, so existing saved learnings become Memories for free (a `KeyLearning` with default SRS state
is simply a never-yet-scheduled insight).

**Reused as-is from `KeyLearning`:**

| Field | Role in Memory |
|---|---|
| `id: UUID` | Stable identity |
| `book: Book?` | Source book relation (inverse `Book.keyLearnings`) |
| `text: String` | The idea / insight body |
| `chapterRef`, `locator: String` | Source pointer back into the summary/book |
| `starred: Bool` | User-flagged importance; can bias scheduling priority |
| `userEdited: Bool` | Whether the user rewrote it (affects regeneration) |
| `createdAt: Date` | Origin date |
| `tags: [String]` | Reused for deck/topic grouping |

**New fields to add to `KeyLearning`** (all defaulted, CloudKit-safe like the existing model):

```swift
// --- SRS state ---
var cardKindRaw: String = CardKind.insight.rawValue
var isScheduled: Bool = false        // false = saved but never entered the deck
var srsEase: Double = 2.5            // FSRS difficulty proxy; reused on reschedule
var srsStability: Double = 0         // FSRS stability (days); 0 until first review
var srsIntervalDays: Double = 0      // current interval
var dueAt: Date?                     // nil = not yet due-scheduled
var lastReviewedAt: Date?
var lastGradeRaw: String = ""        // ReviewGrade rawValue of last review
var repetitions: Int = 0             // successful reps in a row
var lapses: Int = 0                  // count of Again grades

// --- leech / suspension ---
var isSuspended: Bool = false
var suspendedReasonRaw: String = ""  // SuspendReason: leech / userPaused / retired

// --- card payload (kind-specific, nil when unused) ---
var front: String = ""               // cloze/Q&A prompt; defaults to text for insight
var back: String = ""                // answer for cloze/Q&A
var clozeMask: String = ""           // encoded blanked range over `front`
var sourceSummaryID: UUID?           // links micro-lesson / generated card to its summary

// --- teach-back ---
var lastExplanation: String = ""     // user's most recent explanation
var lastScore: Int = -1              // 0-100 LLM grade; -1 = never graded
```

Plus computed accessors mirroring the existing `kind` pattern on `BookVariant`:

```swift
enum CardKind: String, Codable, CaseIterable, Sendable {
    case insight, cloze, teachBack, microLesson
}
enum ReviewGrade: String, Codable, CaseIterable, Sendable {
    case again, hard, good, easy
}
enum SuspendReason: String, Codable, Sendable {
    case none, leech, userPaused, retired
}

var cardKind: CardKind { get { CardKind(rawValue: cardKindRaw) ?? .insight } set { cardKindRaw = newValue.rawValue } }
var lastGrade: ReviewGrade? { ReviewGrade(rawValue: lastGradeRaw) }
```

> **Migration note.** Every new field is defaulted, so SwiftData/CloudKit migration is additive and
> non-breaking. Existing `KeyLearning` rows load as unscheduled insights (`isScheduled = false`),
> and the user opts them into the deck via "Add to memory" with no data loss.

### 4.2 New supporting types

`ReviewSession`: one daily review sitting, for streak/retention analytics (the headline metric is
retention, not streak length):

```swift
@Model final class ReviewSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var cardsReviewed: Int = 0
    var againCount: Int = 0
    var goodOrBetterCount: Int = 0   // the real retention signal
    var memoryIDs: [UUID] = []       // KeyLearning ids touched this session
}
```

`ReviewLog` (optional, per-grade): append-only history per card for FSRS tuning and "your phrasing
improved" views. Kept separate so the Memory record stays small:

```swift
@Model final class ReviewLog {
    var id: UUID = UUID()
    var memoryID: UUID = UUID()      // -> KeyLearning.id
    var reviewedAt: Date = Date.now
    var gradeRaw: String = ""
    var intervalBeforeDays: Double = 0
    var intervalAfterDays: Double = 0
    var score: Int = -1              // teach-back score if applicable
}
```

`StreakState` (lightweight, single record): current streak, last-active day, daily cap, reminder
opt-in. Already named in `PLAN.md` §5. Streak here is cosmetic and never gates review.

The scheduler itself is not a model. It's a pure value-type service (`FSRSScheduler`) that
takes a Memory's SRS fields + a grade and returns updated SRS fields. Keeping it pure makes the
anti-burnout rules (cap, spread, leech) unit-testable without SwiftData.

---

## 5. Retrieval flow

```
Summary (catalog item)
   │
   ├── tap an insight  ──► "Save as Memory"   ──► KeyLearning(cardKind: .insight, isScheduled: true)
   │                                               dueAt = now  (enters today's queue)
   │
   └── "Add whole book" ──► seed all key ideas as Memories
                              dueAt staggered over the next few days so day 1 isn't a wall
                              (respects the §3a cap from the very first session)
                                   │
                                   ▼
                         Daily due queue  (cards where dueAt <= now, capped at dailyLimit,
                                            suspended cards excluded, starred biased earlier)
                                   │
                       ┌──────────┴───────────┐
                  show card            (kind decides UI: insight reveal /
                  by cardKind           cloze blank / teach-back text field /
                                        micro-lesson swipe deck)
                                   │
                              user grades  (Again / Hard / Good / Easy;
                                            teach-back: LLM score → grade)
                                   │
                       FSRSScheduler.next(...) updates
                       srsIntervalDays, srsStability, srsEase, dueAt,
                       repetitions, lapses, lastGrade, lastReviewedAt
                                   │
                       leech check: lapses >= threshold → suspend + offer reformulate
                                   │
                              append ReviewLog; update ReviewSession
```

**Surfaces:**
- **Save points:** the summary reader's insight rows ("Save as Memory") and the summary header
  ("Add whole book"). A saved insight can be promoted to a cloze or teach-back card later.
- **Daily queue:** the Memories tab / home depending on the chosen IA direction (`PLAN.md` §9).
- **Widget:** "today's memory" shows one due card; tapping opens the review queue.
- **Notification:** one gentle daily nudge at the chosen time, count-only copy, opt-in.

The "Add whole book" staggering is load-bearing: seeding 12 ideas must not create a 12-card day,
then a 0-card day, then a re-test wall. Initial `dueAt` is spread across the first few days under the
cap, same machinery as §3b catch-up.

---

## 6. Open questions & phasing

**Ships first (Phase 1, `PLAN.md` §8):**
- Insight + cloze/Q&A card kinds.
- Basic FSRS scheduler with the **capped daily load** and **forgiving catch-up** rules (§3a, §3b).
  These are not optional polish; they are the differentiator against Anki burnout and must be in v1.
- "Save as Memory" + "Add whole book", daily queue, four grade buttons, widget.
- `ReviewSession` for the retention metric.

**Later (Phase 2–3):**
- Teach-back LLM grading (§2c): needs the judge prompt contract validated and on-device routing
  tuned for cost/latency before it goes in the daily loop.
- Leech auto-reformulation (§3c step 2): suspend can ship in Phase 1; LLM rewrite follows.
- Illustrated micro-lesson cards (§2d): gated on the illustration pipeline (`PLAN.md` §4.4, Phase 3).

**Open questions:**
1. FSRS parameter source: ship default weights, or fit per-user weights once enough `ReviewLog`
   data exists? Per-user fitting is a Phase 2+ refinement.
2. Default `dailyLimit` (20?) and `leechThreshold` (8?): set from the anti-burnout intent, validate
   with the interview cohort.
3. Teach-back grading model: Foundation Models on-device for cost, Claude fallback for hard ideas?
   Where's the quality floor for "the idea is present"?
4. Should `starred` Memories get scheduling priority, a slower decay, or no special treatment?
5. Does cloze generation happen at save time (eager, costs tokens up front) or first-review (lazy)?
