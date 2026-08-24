# App Store listing — Epigrapha

> All copy ready to paste into App Store Connect. 30/170/4000/100 character
> limits called out next to each field. Keywords are deliberately conservative
> — the App Store rejects keyword-stuffing and rewards specific, intent-led
> terms.

---

## Name (30 chars)

`Epigrapha — Read, Listen, Adapt`

(28 chars)

## Subtitle (30 chars)

`Books that bend to your time.`

(29 chars)

## Promotional Text (170 chars, editable any time)

`Twenty-eight classics in full, each with a five-minute summary and a two-minute quick take. Pick your length. Listen on-device. Or bring your own EPUBs.`

(151 chars)

## Description (4000 chars)

```
Epigrapha turns every book on your shelf into a tool that bends around your time.

Pick your length
Twenty-eight works of public-domain non-fiction ship complete — Meditations, Walden, On Liberty, The Wealth of Nations, The Souls of Black Folk. Each one also comes with an original five-minute summary and a two-minute quick take, written as idea-level companions with full attribution. Read the whole book, or read the shape of it on the train. Every reading feature works on all three.

Compress or expand
Have an hour, but the book takes ten? Compress it to a summary that keeps the author's voice and every key idea. Or take a short essay and expand it when you want to go deeper. Compression and expansion run on Apple's on-device intelligence where the hardware supports it, and on a cloud AI model (Anthropic) when the text is long or the task is hard — you always see the model and the cost before anything runs, and nothing is sent anywhere until you say so.

Listen, on-device
Every book becomes an audiobook using the best voice installed on your device. The current word lights up as it is spoken, the page flips itself, and lock-screen controls keep working in the background. No cloud round-trip; nothing leaves the device.

Speed read
Read at any pace from 150 to 1,200 words per minute, with the current word highlighted in place so you never lose your position. Pause at punctuation, jump back a sentence, or hand the passage over to the narrator when you find something worth hearing.

Re-style
Six books ship with a re-style already made, no key required: The Art of War staged as Shakespeare, Adam Smith explained by a pirate, Darwin narrated as a nature documentary, Machiavelli as a corporate all-hands memo, Marcus Aurelius as a group chat, Thoreau as a lifestyle blog. Then make your own — a dense chapter as a spare, literary essay, or a book with every reference to a theme you do not care about stripped out.

Keep what matters
Highlight anything worth remembering as you read. It lands in the Saved tab, and one search covers your whole library — books, authors, themes and every passage you kept.

Your library, in iCloud
Your shelf, your reading position, your highlights and your transformations sync across your iPhone and iPad. Books live in your own iCloud Drive, so they are yours, not ours.

Built around great typography
New York for titles, San Francisco for chrome, your choice of font and theme for the page itself. Sepia, light, dark and true black. Margins, line spacing and paragraph gaps are all tunable, and the reader honours your system text size.

Privacy
There is no Epigrapha server and no account. Cloud AI is reached with your own Anthropic API key, which lives in your Keychain. Before any text is sent, Epigrapha asks in a dialog that names Anthropic and says exactly what will be sent — and you can withdraw that permission at any time in Settings, which switches the cloud path off entirely. Automatic category tagging runs on-device only. No analytics, no telemetry, no tracking.

Supported formats
EPUB and PDF.

Epigrapha is free. No subscription, no in-app purchases, no ads. Cloud transformations are optional and use your own Anthropic API key, billed directly by Anthropic.
```

(~2,900 chars — well under limit)

## Keywords (100 chars, comma-separated, no spaces)

```
epub,ebook,reader,audiobook,tts,speed-reading,summary,classics,highlights,public-domain,stoic
```

(92 chars)

> No trademarked terms (no "claude", no "kindle") — 2.3.7 rejects those.

## Support URL

`https://lukataylo.github.io/book-app/support/`

## Marketing URL

`https://lukataylo.github.io/book-app/`

## Privacy Policy URL

`https://lukataylo.github.io/book-app/privacy/`

> All three are published by `.github/workflows/pages.yml` and verified by
> that workflow before it reports success. A GitHub blob URL was used here
> previously; Review treats an un-rendered markdown blob as a dead policy.

## Category

- Primary: **Books**
- Secondary: **Productivity**

## Age rating

**4+** — no objectionable content. (Note: book content itself is user-supplied; the app does not generate or host adult material. The transformation features include user-controlled tone modulation but the model providers' safety guidelines apply.)

## Pricing

**Free.** No in-app purchases, no subscriptions, no ads.

All core features (the bundled summaries, reader, on-device TTS, speed reading, highlights, search, and on-device AI transformations on supported hardware) are free and require no payment and no key. Optional cloud transformations use the user's own Anthropic API key and are billed directly by Anthropic — the app never marks up or collects any cloud cost.

## What's New (4000 chars per version)

Initial release.

```
Hello.
- Catalog: 28 public-domain works in full, each with a five-minute summary and a two-minute quick take.
- Library: import your own EPUB or PDF from iCloud Drive, grouped by category.
- Reader: clean reflowable text, font / margin / theme controls.
- Listen: on-device narration with word-level highlighting.
- Speed read: 150 to 1,200 wpm with the current word highlighted in place.
- Transform: compress, expand, re-style, omit themes.
- Highlights: keep passages, search them across every book.
- Sync: your shelf and your reading position across iPhone and iPad.
```

## Screenshots brief

Five screenshots per device (iPhone 6.9" required; iPad 13" if iPad is
listed). App Review applies 4.3(b) from the screenshots alone in this
category, so the set has to show the thing a summary app cannot show —
**one book at three lengths** — before it shows anything else.

1. **Book page, variants visible** — the hero shot. One title with "Full
   text · 4 h", "The Big Ideas · 5 min" and "Quick take · 2 min" stacked
   and tappable. This is the differentiator; lead with it.
2. **Reader** — a real chapter of a bundled title in serif, sepia theme,
   bottom bar visible.
3. **Listen** — mid-playback with the spoken word highlighted and the
   progress region showing time left.
4. **Library** — filled shelves, so the catalog reads as a library rather
   than a feed of cards.
5. **Transformation Studio** — the estimate card before a run, showing the
   model and the cost. Being explicit about cost is itself a 3.1.1 point.

Caption typography: New York Bold, 56pt, off-white on the cream background,
single sentence each:

1. *One book. Three lengths. Your call.*
2. *Read like Apple Books — your way.*
3. *Every word lit as it's spoken.*
4. *Twenty-eight classics, in full.*
5. *Reshape any book to your schedule.*

Only use titles that actually ship. The old brief named *The
Psychopathology of Everyday Things* and *Pride and Prejudice* — the first
is in copyright and neither is in the catalog. Use Meditations, Walden,
On Liberty or The Souls of Black Folk.

Regenerate with
`xcodebuild test -only-testing:BookAppUITests/StoreShotTests`, and **erase
the simulator first** — a stale store seeded by an older loader key will
put withdrawn titles on the shelf.

## In-app purchase

None. The app is free with no in-app purchases. (A future "Epigrapha+" tier is only an idea and is not part of this submission.)

## Review notes (private to App Review)

```
SUMMARY
Epigrapha is a free personal reading tool. There is no backend and we host
nothing. Most features run entirely on-device; advanced book
transformations can optionally run in the cloud via the user's own
Anthropic API key.

CORE FEATURES WORK WITH NO KEY — PLEASE TEST THESE FIRST
The app is fully usable with no API key and no payment. Without entering
any key the reviewer can:
  - Read all 28 public-domain works in full, plus the original summary and
    quick take that ship with each, and the six re-styles.
  - Use the reader (EPUB/PDF import, fonts, themes, margins).
  - Use on-device narration with word-level highlighting.
  - Highlight passages and find them again from the Search tab.
  - Use speed reading, 150-1,200 wpm.
None of these features require a key, an account, or a purchase. We ask
that the reviewer test these first to confirm the app delivers value
out of the box.

PRICING (Guideline 2.3.1)
The app is FREE with no in-app purchases and no subscriptions. We do not
sell, mark up, or collect any cloud cost. Optional cloud transformations
are billed by Anthropic directly to the user's own pre-paid Anthropic
account.

BRING-YOUR-OWN-KEY MODEL (Guideline 3.1.1)
Cloud transformations use the user's own Anthropic API key, entered in
Settings → AI and stored only in the iOS Keychain. The key is not a
purchase of digital content inside the app; it authenticates the user's
own pre-existing, pre-paid Anthropic account, and Anthropic bills the
user directly for any usage. Because the app is free, has no IAP, and all
core features work without a key, the optional key does not unlock paid
in-app content and is not subject to IAP requirements.

ON-DEVICE AI REQUIRES iOS 26+ — TEMPORARY KEY FOR TESTING
On-device AI transformations need Apple Intelligence (iOS 26 or later on
supported hardware). So the reviewer can exercise the cloud
transformation path on any device, we are providing a temporary Anthropic
API key in the App Review Information field. Please add it in
Settings → AI to test compress / expand / re-style. It can be revoked
after review.

NO ACCOUNT SYSTEM (Guideline 5.1.1(v))
The app has no account system — no sign-up, no login, no username or
password. User data lives on-device and in the user's private iCloud
(CloudKit private database) under their own Apple Account. Because there
is no account to create, there is no account to delete, so the
account-deletion requirement does not apply.

DIFFERENTIATION (Guideline 4.3(b))
Epigrapha is not a generic summary catalogue. It is a full reading
environment with capabilities not offered by apps such as Blinkist or
Headway:
  - Import and read the user's own EPUB and PDF files.
  - Word-level highlighting synced to on-device text-to-speech.
  - Elastic length on a single title: the same work as a two-minute quick
    take, a five-minute summary, or the complete text — a summary app
    ships only the summary.
  - On-device AI transformations (compress / expand / re-style) that run
    locally on supported hardware with no cloud round-trip.

THIRD-PARTY AI CONSENT (Guideline 5.1.2(i))
No user content reaches Anthropic until the user grants permission in a
dialog that names Anthropic and states what will be sent. The gate is
enforced at the network boundary, not at the call site: ClaudeProvider
reports itself unavailable without consent, so the router cannot select
it and no code path can transmit by forgetting to ask. Consent is
withdrawable at any time in Settings -> Privacy, which disables the cloud
path entirely. Automatic category tagging of imported books runs
on-device only and never falls back to the cloud.

CONTENT AND RIGHTS
Every catalog title is a work published before 1930 whose US copyright
has expired; the source text comes from Project Gutenberg, Project
Gutenberg Australia and Wikisource. The accompanying summaries are
original prose written for this app, not extracts, and each one carries
an attribution line naming the source work and stating that the app is
not affiliated with the author or their estate. Cover art is original
vector work; no jacket is reproduced. A contact route for rights concerns
is published at https://lukataylo.github.io/book-app/support/
The app does not generate or host adult content. User-imported books are
the user's own files and outside our scope.

ACCESSIBILITY
The reader honours Dynamic Type, including the accessibility sizes.
VoiceOver labels are provided for the reader, library and playback
controls; cover art is marked decorative so it is not read aloud.
```
