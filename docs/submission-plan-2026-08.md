# App Store submission plan

_Audit of the tree at HEAD + uncommitted work, 2026-08-23. Supersedes the
code findings in `appstore-rejection-mitigations.md` and
`pre-submission-review.md`, both of which pre-date the scope-down and
describe features (Remember, Act, Daily Review, ~80 packs) that no longer
ship._

Everything below is in scope except brand assets — icon, screenshots and
the App Store Connect record itself.

---

## What the research says has changed for 2026

Four shifts matter for this app:

1. **4.3(b) was widened in 2026** to reject apps in saturated categories
   that don't offer "a meaningfully different or improved experience".
   Reviewers now apply it to AI apps from the *screenshots alone* when the
   layout looks like every other submission. A summary-catalogue reading
   app is squarely in a saturated category.
2. **5.1.2(i) (Nov 2025)** requires named, pre-transmission consent before
   user content reaches a third-party AI. This is the single most
   dangerous item here, and the app currently violates it in two places.
3. **Privacy manifests are hard rejections now** (ITMS-91053), not
   warnings, with no grace period — for the app *and* every bundled SDK.
4. **2.3.1 metadata accuracy** is being enforced against feature claims,
   not just screenshots. The listing describes four things the app no
   longer does.

Sources: [App Store rejection reasons 2026](https://qawerk.com/blog/app-store-rejection-reasons/),
[Guideline 4.3 and AI apps](https://ptkd.com/journal/rejection-guideline-4-3-ai-spam),
[privacy manifest enforcement](https://www.avanderlee.com/xcode/missing-api-declaration-required-reason-itms-91053/).

---

## Blockers

### B1 — 5.1.2(i): book text reaches Anthropic with no consent

Two distinct holes, both real:

**a) Auto-tagging on import.** `ImportService.autoTag` fires after every
import and calls `router.run(.categoryTagging, …)`. The routing plan is
`[.appleFoundation, .claudeHaiku4_5]`. On any device without Apple
Intelligence — which is *every reviewer device on production iOS*, and
every phone below the hardware bar — the local provider reports
unavailable and the router falls straight through to Anthropic. A sample
of the user's imported book is transmitted silently, in the background,
with no gate, no confirmation and no UI at all.

**b) The Studio's gate checks the wrong thing.** `startRun()` asks
`resolvedModel.providerID == .anthropic`. `resolvedModel` is the
*preferred* model. When Apple Intelligence is present the answer is
`.appleFoundation`, so no consent is shown — but `LLMRouter.plan` still
lists cloud fallbacks, and a local failure (`providerUnavailable`,
`decodingFailed`, a throw mid-chunk) falls through to Claude and sends the
text anyway.

**Fix: move the gate to the boundary.** `ClaudeProvider` is the only place
in the app where text actually leaves the device. Make
`ClaudeProvider.isAvailable()` return false without consent, so the router
skips it exactly the way it skips a missing API key, and have the
Transformation Studio present the gate when the router reports that cloud
is the only remaining option. One choke point instead of a guard at every
call site — and by construction there is no path to `api.anthropic.com`
that bypasses it.

Auto-tagging then becomes local-only, which is what it should always have
been: it is a nice-to-have that silently fails, so it must never be a
reason to transmit a book.

### B2 — Privacy Policy URL 404s

`https://lukataylo.github.io/book-app/privacy` returns **404**, and so does
the Pages root. It is linked from Settings → About *and* is the URL for
the App Store Connect privacy field. A dead privacy URL is a reliable
rejection.

**Fix:** publish `AppStore/privacy.md` via GitHub Pages, add a workflow
that does it, and verify both the page and the in-app link resolve.

### B3 — "Reset all content" permanently empties the app

`SettingsView.resetAllContent` clears `SummaryPacks.loadedSlugs-v2`. The
loader's key is now `SummaryPacks.loadedSlugs-v4`. The stale key means the
re-seed guard is never cleared, so after a reset the catalog never comes
back — the library is empty forever, on a device that cannot be recovered
without deleting the app.

A reviewer looking for a data-deletion path will find this button.

**Fix:** have the loader own its key and expose a `resetSeedFlag()`, so the
two can never drift again. Add a test.

### B4 — 2.3.1: the listing describes an app that no longer exists

| Claim | Reality |
|---|---|
| "Supported formats: EPUB, PDF and MOBI" | `MOBIConverter` is a stub that always throws "convert with Calibre" |
| "Three modes — paragraph + word highlight, single-word focus, and Spritz-style RSVP" | One mode: in-place word highlighting at a chosen WPM |
| "Original 15-minute summaries" | ~1,100 words ≈ 5 minutes; reading times are now computed |
| "sync across iPhone, iPad and Mac" | `supportedDestinations: [iOS, iPadOS]`, `LSRequiresIPhoneOS = true` |

Onboarding panel 1 also says "Drop in EPUBs, PDFs, even MOBI", and the
README repeats the three-modes and MOBI claims.

**Fix:** correct all copy, and remove MOBI rather than describing it (below).

---

## High

### H1 — Remove MOBI end to end

`Info.plist` declares `com.amazon.mobi8-ebook` and
`com.amazon.mobipocket-ebook` document types, so iOS offers Epigrapha as a
handler for `.mobi` files and the app then always fails. Advertising a
format the app cannot open is both a 2.3.1 problem and a bad first
impression.

Delete the UTIs, `MOBIConverter`, the `.mobi` case, and every mention.
Ship the two formats that work.

### H2 — Support URL is a `mailto:`

App Review expects a reachable support *page*. `mailto:luka.dadiani@me.com`
also publishes a personal address in the app binary and the store listing.

**Fix:** point support at a GitHub Pages support page (published by the
same workflow as the privacy policy).

### H3 — Nutrition label must declare User Content → Anthropic

`data-safety.md` already has the right answer; it has to actually be
entered in App Store Connect. Review cross-checks the label against
observed network behaviour, and the app does contact `api.anthropic.com`.

### H4 — 4.3(b) differentiation must be visible, not just argued

The review notes make the case well. The screenshots have to make the same
case without being read: the differentiators are the length tiers on one
book (full text / summary / quick take), the word-synced Listen mode, and
importing your own files. A screenshot set that opens on a grid of summary
cards looks like every other entry in the category.

---

## Medium

- **M1 Dynamic Type.** 26 hardcoded `.font(.system(size:))` — 14 in
  `ReaderView` chrome. Reading body text is already user-controlled, but
  the chrome doesn't scale.
- **M2 Accessibility labels** are thin outside the reader: the
  Transformation Studio has one, Settings and Saved have none.
- **M3 Dead settings.** `SpeedReaderSettings.commaPauseMS` and
  `periodPauseMS` are referenced only by the model.
- **M4 Screenshots brief** references *The Psychopathology of Everyday
  Things* (in copyright, not in the catalog) and features that were cut.

---

## Confirmed clean (no action)

- **ITMS-91053.** Readium's ZIPFoundation ships its own
  `PrivacyInfo.xcprivacy` declaring File Timestamp (`3B52.1`). The app's
  own manifest declares UserDefaults (`CA92.1`) and nothing else, which
  matches what the code actually uses now that `MetricsLog` is gone. The
  old "watch-item" in `appstore-rejection-mitigations.md` is resolved.
- `ITSAppUsesNonExemptEncryption = false`, `LSRequiresIPhoneOS = true`,
  background audio mode justified by Listen, sandbox + iCloud entitlements
  consistent with the container.
- No `try!`, `fatalError`, or `as!` anywhere in the app target.
- No unguarded `print` in Release — the loader's are `#if DEBUG`, `DevSeed`
  is `#if DEBUG` at file scope.
- 5.1.1(v) account deletion: no accounts exist, so it does not apply.
  Reset-all-content exists (and B3 fixes it).

---

## Order of work

1. B1 consent boundary, B3 reset key, H1 MOBI removal — code, with tests.
2. B4 + H2 copy, and the Pages workflow for B2.
3. M1–M3 polish.
4. M4 + screenshots — needs the brand assets that are out of scope here.
