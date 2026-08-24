# Proposal: YAGNI pass, real books in the catalog, a better voice

_Read-only review at `6c2c46a` (branch `scope-down-appstore-submission`), 2026-08-23._

Three asks, answered in order. Each section ends with what I'd skip and when to
add it back.

---

## 0. Where the code actually is

| | |
|---|---|
| App Swift | 11,360 lines, 65 files |
| Tests | 15 files |
| Catalog | 28 JSON packs, ~1,100 words of summary each, 376 KB total |
| Bundled resources | 7.8 MB covers, 3.7 MB assets, 200 KB localisations |
| Network destinations | `api.anthropic.com` only |

The last two commits already did a scope-down (Remember + Act cut, ~50
in-copyright packs withdrawn, 7 SPM packages dropped). So the easy fat is gone.
What's left is the harder kind: scaffolding for a v2 that hasn't happened, and
one product-shaped hole.

---

## 1. Full YAGNI refactor

Ranked by lines removed per unit of risk. Everything here is deletion, not
rewriting.

### Tier 1 — delete outright (~600 lines, zero behaviour change)

**1.1 Pre-launch migration machinery.** The app has never shipped to the App
Store, so there is no "existing CloudKit data" to migrate. Delete
`BlobMigration.swift` (108 lines), the `Book.coverData` / `BookVariant.contentText`
legacy in-row fields, and every dual-path read that branches on them
(`Book.coverImageData()`, `BookVariant.loadText()`, `ReaderViewModel.init`'s
"best-effort sync init"). One storage path instead of two, and
`ReaderViewModel` loses its trickiest comment.
_Caveat: if a TestFlight build is already on other people's devices with real
data, keep it. That's the only condition._

**1.2 Dead LLM surface.** `LLMTask` has 12 cases; 4 are unreachable
(`keyLearningsExtraction`, `knowledgeCards`, `actionPlan`, `quizGeneration`,
`chatWithBook` — leftovers from the cut Remember/Act features). They still
carry routing-plan entries in `LLMRouter.plan(for:)` and two prompt builders in
`PromptTemplates` (`keyLearnings`, `chatWithBook`). Delete the cases, the plans,
the templates. `VariantKind.expanded` is likewise never constructed since the
length slider went one-way in `6c2c46a`.

**1.3 MetricKit diagnostics.** `MetricsLog` (99 lines) + the Settings →
Diagnostics section + the share sheet write MetricKit payloads to
`Library/Caches/` so a user can email them to nobody. There is no inbox. It also
costs you a `C617.1` File-Timestamp declaration in the privacy manifest. Cut it
and drop the declaration; Xcode Organizer already gives you crashes and hangs
for free once you ship.

**1.4 MLX scaffolding.** `project.yml` carries a commented-out `MLXSwift`
package and a commented dependency; `LocalProvider` has the fallback hook;
`docs/architecture.md` and the README both advertise "with MLX-Swift fallback".
The pre-submission review already flagged shipping a named-but-broken model as a
2.1 risk. Delete the comments and the hook, fix the two docs.

**1.5 `SavedView`.** A four-line wrapper whose body is `BookmarksGalleryView()`.
Point the tab at the gallery.

### Tier 2 — collapse duplication (~350 lines)

**2.1 Three image files, one job.** `CoverImageCache` (137) + `InlineImageCache`
(88) + `ImageDecoding` (94) are three files implementing "decode a JPEG off the
main thread and keep it in an `NSCache`". One `ImageCache` with two keyspaces is
the same behaviour in ~90 lines.

**2.2 `MarkingsSheet` vs `BookmarksGalleryView`.** Both render "highlights and
bookmarks in two tabs"; one is scoped to a book, one is global. 148 + 372 lines
for one list with a predicate. Make the gallery take an optional `Book?` filter
and delete the sheet.

**2.3 `ReaderView` at 1,501 lines.** Not a delete — a split. Speed-reading is
~200 lines of ticker/word-advance state (`startSpeedTicker`, `advanceSpeedWord`,
`skipSpeedForward`, `rewindSpeedSentence`, `currentSpeedWord`) sitting in the
view, mirroring TTS state that already lives in an engine. Move it to a
`SpeedReader` `@Observable` next to `TTSEngine` and the view drops to ~1,100.
This is the only item here I'd call refactoring rather than deletion, and I'd do
it last.

### Tier 3 — product decisions, not code decisions

**3.1 Seven languages of chrome for an English-only catalog.**
`Localizable.xcstrings` is 197 KB, 207 keys × en/de/es/fr/ja/pt-BR/zh-Hans. Every
one of the 28 books is English. A German speaker gets a German tab bar and 28
English books. This is a tax on every future string change for zero delivered
value. Ship English; add a locale the day content exists in it.

**3.2 Stale model IDs.** `LLMModel` names `claude-sonnet-4-6`, `claude-opus-4-7`
and `claude-haiku-4-5-20251001`. Current IDs are `claude-opus-5`,
`claude-sonnet-5`, `claude-haiku-4-5` (no date suffix — the suffixed form is a
different, older string). Prices in the enum are also stale: Opus is now
$5/$25 per MTok, not $15/$75. Fix the enum, fix the README's "Sonnet 4.6 /
Opus 4.7" line.

**3.3 Dead keys in two packs.** `meditations.json` and
`letters-from-a-stoic.json` still carry `cards` and `actions` blocks (15.7 KB)
from the cut features. The decoder ignores them. Strip them so the schema and
the files agree.

### What I'd skip

Skipped: rewriting `EPUBParser`, touching `TransformationEngine`'s map-reduce,
and any new abstraction over the two remaining LLM providers. Add when a third
provider or a third file format actually arrives.

**Net: roughly 1,000 lines and 200 KB out, no user-visible change.**

---

## 2. Full database update: real books next to the summaries

### The problem, stated precisely

The catalog ships 28 summaries of public-domain books and **not one of the
books**. Every card reads "3–15 min" — but the summary is ~1,100 words, which is
4½ minutes at 250 wpm, not 15. All 28 packs hard-code `read_minutes: 15`. So the
app currently overclaims by 3× on the only content it ships.

Meanwhile the actual works — Meditations, Walden, On Liberty, The Republic — are
free, unencumbered, and exactly the thing a reading app should contain.

### The lazy shape

Don't add a new content type. A book already has variants. Add one.

```
Meditations (Marcus Aurelius, 180)
  ├─ Full text          .original     ~55,000 words   4 h        ← new
  ├─ The Big Ideas in…  .compressed   ~1,100 words    5 min      ← today's .original
  └─ Quick take         .compressed   ~350 words      2 min      ← exists
```

That is semantically what these things are: the summary *is* a compression of
the original. Nothing in the reader, TTS, chapter list, search, bookmarks or the
Transformation Studio needs to change — they all operate on a variant. The
variant picker in `BookDetailView` becomes the feature.

Consequences that fall out for free:

- `totalWordsEstimate` / `totalPagesEstimate` become real, so "time left" and
  the page counter stop lying.
- `read_minutes` gets computed from the word count per variant instead of being
  a constant 15. Fix the overclaim by deleting the field.
- The IP posture improves: the riskiest artefact in
  `docs/content-legal-review.md` was the summary standing alone. Shipping it as
  a companion to a full public-domain text it's manifestly not a substitute for
  is a materially better story.
- The Transformation Studio gets something worth transforming. "Compress
  Wealth of Nations to 20 pages" is the README's headline claim and today there
  is no 400-page book in the app to run it on.

### Sourcing

I measured it. Project Gutenberg plain text for the 28 titles:

| | |
|---|---|
| Raw UTF-8 | **32.3 MB** |
| Gzipped (measured 2.5:1 on Walden) | **~13 MB** |
| Largest single title | Decline and Fall, 10.7 MB (6 volumes, one third of the total) |
| Auto-matched by search | 24 of 28 |

So the whole corpus roughly doubles the app's resource footprint to ~25 MB —
comfortably inside the 200 MB cellular limit, no ODR needed for text.

Four titles need a hand-picked ID rather than a search hit, and they're the ones
worth a second look anyway:

- **Self-Reliance** — only exists inside *Essays: First Series*; extract the essay.
- **A Room of One's Own** — 1929, so US public domain only since Jan 2025. Confirm before shipping.
- **Letters from a Stoic** — ship the Gummere translation (PD); the popular Campbell translation is not.
- **The Voyage of the Beagle** / **Theory of the Leisure Class** — search matched the wrong work; IDs 944 and 833.
- **Decline and Fall** — consider shipping volume 1 only. 10.7 MB for a book
  nobody finishes is a bad trade.

### The one-time job

A script in `scripts/`, run once, output committed:

1. Curated `slug → Gutenberg ID` map (28 lines, hand-checked, not a search).
2. Download `.txt.utf-8`, strip the PG header/trailer boilerplate — this also
   strips the trademark, which is what keeps the PG license from attaching.
3. Convert `CHAPTER I` / `BOOK II` style headings to the `# Heading` marker the
   reader, chapter list and TTS already understand.
4. Write `BookApp/Resources/FullTexts/<slug>.txt`.

Then `SummaryPackLoader` gains ~20 lines: bump the key to `-v4`, insert the full
text as `.original`, re-kind the existing summary as `.compressed`, recompute
word counts. The prune path already handles withdrawal.

### What I'd skip

Skipped: Standard Ebooks (better typography, but they bot-block scripted
downloads and the win is marginal once you're stripping to plain text anyway),
per-title EPUB packaging, a downloadable store, and adding new titles. Get the
28 you already have covers and summaries for. Add titles when the 28 are solid.

---

## 3. Speech: on-device generation — blocked on MLX, evidence below

_Updated after attempting the build. The route chosen (KokoroSwift +
On-Demand Resources) does not survive contact with the iOS Simulator._

### What shipped

`TTSEngine.bestVoice(matching:)` — the reader now picks the
highest-quality installed voice instead of the system default.
`AVSpeechSynthesisVoice(language:)` returns the *compact* voice, the flat
robotic tier, even when a Premium (Siri) voice is installed; it also has
a known iOS 26 regression where it ignores the voice chosen in
Accessibility settings. Ranking the installed set ourselves avoids both.
`onlyCompactVoicesInstalled` is there for Settings to offer the one-tap
route to iOS's voice downloads, which is where the good voices live and
where almost nobody looks.

That is the whole free win. It does not make Samantha sound like a
narrator; it makes sure you are hearing the best voice the device
already has.

### What blocked

Kokoro-82M via `mlalma/kokoro-ios` (MIT) is the right on-device model,
and the integration got most of the way:

| Step | Result |
|---|---|
| Metal toolchain (687 MB, `xcodebuild -downloadComponent`) | installed, Metal shaders compile |
| SPM identity clash: Readium's ZIPFoundation 3.x vs MLX's 0.9.x | resolved by porting `EPUBParser` to upstream weichsel 0.9.20 |
| **iOS device build, signed, real team** | **BUILD SUCCEEDED** |
| **iOS Simulator build** | **fails to link** |

The simulator failure is not fixable from this side:

```
"_MTLTensorDomain", referenced from: ... in device-*.o
ld: symbol(s) not found for architecture arm64
```

`MTLTensorDomain` is present in the iOS **device** SDK and absent from
the iOS **Simulator** SDK — confirmed by grepping both
`Metal.framework/Metal.tbd` files. MLX Swift 0.30.2 references it
unconditionally, so anything linking MLX cannot build for the simulator.

And it cannot be upgraded out: `kokoro-ios` 1.0.11 pins `mlx-swift`
to **exactly** 0.30.2, so a newer MLX needs a fork. (MLX 0.31.6 also adds
a `CudaBuild` build plugin that requires interactive trust approval —
its own CI problem.)

Two further papercuts, both simulator-only: `KokoroSwift` and
`MisakiSwift` declare resources with `.copy("../../Resources/")`, which
produces a macOS-shaped bundle that iOS codesign rejects with "bundle
format unrecognized, invalid, or unsuitable".

### Why that is disqualifying as-is

Linking MLX makes the whole app un-buildable for the simulator. The 59
unit tests run there. So the cost is not "the neural voice is
device-only" — it is "the test suite and all simulator development stop
working the moment the package is linked".

The Core ML route does not dodge this: `MisakiSwift`, the
grapheme-to-phoneme step, itself depends on `MLXUtilsLibrary` →
`mlx-swift`. Any Kokoro path through the existing Swift ecosystem drags
MLX in.

### The three ways forward

1. **Fork `kokoro-ios`** to loosen the `mlx-swift == 0.30.2` pin, and
   verify a newer MLX guards the device-only symbols. One-line fork, but
   speculative — I could not confirm 0.31.6 links on the simulator
   because its build plugin blocks a non-interactive build.
2. **Accept device-only**, and keep the simulator building by not linking
   the package at all in that configuration. SwiftPM platform conditions
   distinguish iOS from macOS, not device from simulator, so this needs a
   separate target or an XcodeGen config split — real structural work.
3. **Write the phonemiser** (CMUdict + letter-to-sound fallback, BSD
   licensed) and run Kokoro through Core ML. No MLX anywhere, works on
   simulator and device, runs on the Neural Engine. The most code
   (~300 lines of inference pipeline plus the G2P) and the only route
   with no third-party runtime dependency at all.

My recommendation is 3, on the grounds that it is the only one that
leaves the project with fewer moving parts than it started with — but it
is also the only one where I cannot verify the audio is correct without
you running it on a device.

### The podcast

Unblocked either way, and independent of which engine renders it: one new
`LLMTask` plus a `PromptTemplates` entry turns a variant into a two-host
transcript, and `AVSpeechSynthesizer.write(_:toBufferCallback:)` already
renders offline to an `AVAudioFile` with no key and no network. That is a
real two-voice podcast today at system-voice quality, and it upgrades for
free the moment a better renderer exists. Not started — it was queued
behind the engine.

## Suggested order

1. **§1 Tier 1** — pure deletion, lands in a day, makes everything after it smaller.
2. **§2** — the biggest product gain per line written, and it's mostly a script.
3. **§3 podcast, free path** — two-voice scripts rendered offline by the
   synthesiser already in the app. No new dependency, no blocker.
4. **§3 on-device neural voice** — pick one of the three routes above.

Steps 1 and 2 are done and green. Neither blocks submission.
