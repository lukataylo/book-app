# App Store Readiness & Quality Review

_Multi-agent read-only audit (6 reviewers: submission/compliance, dead code, code quality, UX/accessibility, recent-changes/data, performance)._

Overall: the app is genuinely well-built (reduce-motion handling, real empty states, CloudKit fallback, MetricKit, clean live UI). No insurmountable blockers. The real work is (a) two trivial plist/manifest fixes, (b) the IP posture of the summary packs, (c) a handful of **regressions and half-wired features** in the recent changes, and (d) polish for a credible 1.0.

---

## 1. Submission blockers (must fix to upload)

| # | Severity | Item | Fix |
|---|---|---|---|
| 1 | High | `ITSAppUsesNonExemptEncryption` missing from Info.plist → every upload stalls on export compliance | Add `ITSAppUsesNonExemptEncryption = false` (HTTPS-only is exempt) |
| 2 | High | Undeclared **File Timestamp** required-reason API — `Services/Diagnostics/MetricsLog.swift:56-61` uses `.contentModificationDateKey` but `PrivacyInfo.xcprivacy` doesn't declare it → ITMS-91061 | Add `NSPrivacyAccessedAPICategoryFileTimestamp` reason `C617.1` |
| 3 | High (legal) / Med (review) | **80 "The Big Ideas in <real book>" summary packs** using real titles/authors. Defensible (ideas aren't copyrightable; disclaimer + "buy the book" shown) but the most likely cause of a post-launch Guideline 5.2 / DMCA takedown | Spot-check all 80 for verbatim/close paraphrase; keep disclaimer on every summary surface; original cover art only (✓ done); be ready for per-title takedown |
| 4 | Required (external) | Screenshots (iPhone 6.7" + iPad 12.9"), reachable Privacy Policy + Support URLs, **production** CloudKit container + App Group, reviewer Anthropic key | Supply in App Store Connect |

Non-blocking submission nits: remove unused `NSAppleMusicUsageDescription` + macOS mic/movies sandbox entitlements; add an `AccentColor` set (clears build warning); `LSRequiresIPhoneOS=true`; add a Readium/BSD-3 license attribution screen.

---

## 2. Bugs & regressions (highest priority — several introduced by the recent work)

- **[High] SVG covers ship DARK to existing/TestFlight users.** `SummaryPackLoader.runIfNeeded` early-returns when all slugs are already loaded (`:38-39`), so the `artSlug` backfill inside `seed()` never runs; `SeedBooksLoader` is gated by `SeedBooks.completed-v1`. Only **fresh installs** get the new covers. → Bump `loadedSlugsKey` to `-v2` + add a one-time `artSlug` backfill migration for the 3 seed books.
- **[High] Daily Review is broken for the default content.** Insight cards (`KeyLearning`, the default `kind`) have `promptText == text` and empty `back`, so "Show idea" (`ReviewSessionView.swift:59`) reveals nothing — the user self-grades text that was never hidden. → Generate a real question-front / idea-back (or cloze) for review cards.
- **[High] "Save" and "Review" are disconnected.** Saving a `KnowledgeCard` in a Remember deck does **not** enroll it; Daily Review operates on a different model (`KeyLearning`). `enrollSavedIdeas` bulk-schedules **every** unscheduled learning (~400 across the catalog), labelled misleadingly as "saved ideas." → Unify on one savable idea entity, or make Daily Review draw from saved cards + add a per-idea "Add to review."
- **[Med] `again` cards never re-surface in a session.** `ReviewSessionView` captures the queue once (`:199`) and only advances `index`; the scheduler's 10-min relearn step is dead at the UI. → Re-append on `again` or rebuild from `dueToday` at end.
- **[Med] Empty `ReviewSession` rows accumulate** — inserted in `start()` on every appearance incl. empty state; `enrollSavedIdeas` orphans one. → Insert lazily on first grade.

---

## 3. What's missing / still needs adding (for a credible 1.0)

- **Review reminders / local notifications** — zero `UNUserNotification` usage. A spaced-repetition app with no "a card is due" nudge is the single biggest retention gap.
- **Settings is bare** (`About` = just "Version 1.0"). Add: Privacy Policy, Licenses & Attribution (required for the bundled book content, Guideline 5.2), Contact Support, **Reset all data**, review-reminder toggle, ability to remove a stored API key.
- **Onboarding omits the Remember/Daily-Review story** — the product's differentiator is never mentioned.
- **No per-idea "Add to review"** from a deck/Saved; **deck end-card dead-ends** when no plan exists (offer "Create a 14-day plan").
- Generation calls (Remember/Act) show no progress/cancel.

---

## 4. Dead code & dead buttons

Live UI is clean — **no no-op buttons in shipping screens.** Dead surface is concentrated:

- **[High] `SpeedReaderView.swift` (338 lines) is an orphan** — speed reading was reimplemented inline in `ReaderView`. Never instantiated. → Delete file + folder + the now-dead `SpeedReaderSettings` fields (`modeRaw`, `focusPoint`, `paragraphPauseMS`, `chunkSize`, `highlightColorHex`).
- **[High] FSRS "Phase 2" is built + unit-tested but reachable from no UI:** `CardGenerator` (cloze), `TeachBackGrader.grade`, `MemoryStore.addWholeBook` / `reinstate`, `ReviewQueue.meterOverdue` / `seedDueDates`, `FSRSScheduler.isLeech`, `StreakState.registerActivity`, the `clozeFromIdea`/`reformulateCard`/`teachBackGrading` prompts, and the `.cloze`/`.teachBack` card kinds + `teachBackScore` param. → Product call: **wire up** (teach-back mode, per-book enroll, streaks, leech reinstate) **or delete**.
- **[Low]** `SettingsView` `keySaved` state written-never-read; `TransformationStudioView` `SectionCard.disabled` param unused; release-build `print(...)` in `SeedBooksLoader`/`SummaryPackLoader` (gate behind `#if DEBUG`).

---

## 5. What can be simplified

- **Cover rendering is triplicated** (`BookCardView.cover`, `BookDetailView.cover`, macOS branch) and the **detail path bypasses the cache** — it decodes the JPEG synchronously in `body` on every render (the exact regression `CoverImageCache` exists to prevent), and uses a 110×165 frame vs 110×160 elsewhere. → Extract one `BookCoverView(book:size:)` routed through `CachedCoverImage`.
- `RememberView.reviewBanner` does **two unbounded SwiftData fetches per render** (inside `body`, re-runs per search keystroke). → One fetch returning `(due, waiting)`.
- `try? context.save()` silently swallows failures on load-bearing paths (e.g. `MemoryStore.grade`). → Log on review-state writes.

---

## 6. Performance (top wins)

1. **N+1 relationship faults in `RememberView`/`ActView` `body`** — `books.filter { $0.knowledgeCards }` etc. faults ~160 SQL round-trips per body eval, and `body` re-runs **per search keystroke**. → Maintain scalar columns (`hasCards`/`cardCount`/`hasPlan`/`hasOriginalText`) in the loaders; filter on those.
2. **`reviewBanner` double unbounded fetch + sort per render** (see §5). → single bounded fetch, move out of `body`.
3. **`UIImage(named:)` cover probe per card per render** + vector re-rasterization on the main thread (`preserves-vector-representation`). → Resolve name from `artSlug` without the probe; consider shipping covers as decoded raster scales for the ≤120pt sizes used.
4. Cold launch: `SeedBooksLoader` parses 3 EPUBs on the main actor; `SummaryPackLoader` does 80 sequential main-actor saves. → Parse off-main; batch saves.
5. Summary-pack `contentText` is stored in-row and only moved to disk by a one-shot `BlobMigration` — packs added in a later update keep text in-row forever (bloats CloudKit). → Write variant text straight to disk in `SummaryPackLoader` (as `SeedBooksLoader` already does).

---

## 7. Accessibility

- **[High] Covers leak `cover-atomic-habits` filenames to VoiceOver** and `GeneratedCoverView` draws real `Text(title/author)` **inside the artwork**, duplicating the caption → every shelf title read twice. → `accessibilityHidden(true)` on the cover + one combined card label.
- **[High] Hardcoded `.font(.system(size:))`** across onboarding + most sheets (Chapter/Markings/Search/PDF/TTS/EditMetadata) → won't scale with Dynamic Type. → Use text styles; reserve fixed sizes for cover canvas + the big speed-reader word.
- **[Med]** No haptic on the most-repeated action (review grade); reduce-motion not honored in review/onboarding; a few sub-44pt hit targets; `textSecondary` at `.opacity(0.7)` fails WCAG AA.

---

## 8. Data layer (verified safe)

- **Schema/migration PASS:** all 14 `@Model` types registered in both schema blocks; every new field additive + defaulted; no `@Attribute(.unique)`; relationship inverses correct; `ReviewLog`/`ReviewSession` reference `KeyLearning` by UUID (sound).
- **[Med] Multi-device first-launch seed duplication** — UserDefaults guards are per-device; two devices seeding before CloudKit converges insert duplicate packs. Pre-existing; widened by the 80-pack volume. → Consider a synced (`NSUbiquitousKeyValueStore`) seed flag or a post-sync title de-dup sweep.

---

## Recommended fix order

1. **Submission one-liners** (§1.1, §1.2) — trivial, unblock upload.
2. **Regressions I introduced** (§2: artSlug backfill, cover a11y/perf, cover de-triplication) — restore correctness for upgraders.
3. **Daily Review coherence** (§2: real review cards, save↔review wiring, again-in-session) — make the headline feature actually work.
4. **Dead code** (§4: delete SpeedReaderView; decide wire-vs-delete on FSRS Phase 2).
5. **1.0 must-adds** (§3: reminders, Settings, onboarding).
6. **Perf + a11y passes** (§6, §7).
7. **IP spot-check** (§1.3) before submitting.
