# App Store listing — BookApp

> All copy ready to paste into App Store Connect. 30/170/4000/100 character
> limits called out next to each field. Keywords are deliberately conservative
> — the App Store rejects keyword-stuffing and rewards specific, intent-led
> terms.

---

## Name (30 chars)

`BookApp — Read, Listen, Adapt`

(28 chars)

## Subtitle (30 chars)

`Books that bend to your time.`

(29 chars)

## Promotional Text (170 chars, editable any time)

`Compress a 400-page book to a 20-page summary. Expand notes into full chapters. Listen on-device. Speed-read with paragraph and word highlighting. Your shelf, in your pocket.`

(170 chars)

## Description (4000 chars)

```
BookApp turns every book on your shelf into a tool that bends around your time.

Read, Remember, Act
Start with the big ideas: original 15-minute summaries of major non-fiction, written as idea-level companions with full attribution. Turn any book into a deck of swipeable knowledge cards — one idea per card — and save the keepers. Then put the book to work: a 14-day action plan per title, checkable in-app or exported straight to your Calendar (write-only) and Reminders.

Compress or expand
Have an hour, but the book takes ten? Compress it to a 20-page summary that keeps the author's voice and every key idea. Or take a five-page essay and expand it to a full chapter when you want to go deeper. Compression and expansion run on Apple's on-device intelligence when possible, and on a cloud AI model (Anthropic) when the text is long or the task is hard — you always see the model and the cost before anything runs.

Listen, on-device
Every book becomes an audiobook with the system's premium voices. The current word lights up as it's spoken, the page flips itself, and lock-screen controls keep working in the background. No cloud round-trip; nothing leaves the device.

Speed read
Three modes — paragraph + word highlight, single-word focus, and Spritz-style RSVP — at any pace from 150 to 1,200 words per minute. Pause at punctuation, jump back a sentence, hand it off to TTS when you've found a passage worth hearing.

Re-style
Make a dense academic chapter read more like a spare, literary essay. Strip every reference to a theme you're not interested in. Try a single chapter as a different voice before committing to the whole book.

Key learnings
Pull 5 to 15 key learnings from any book in seconds. Edit, star, export to Markdown or JSON. Quiz yourself with auto-generated flashcards.

Your library, in iCloud
Your shelf, your reading position, your annotations, your transformations — all sync across iPhone, iPad and Mac. Books live in your iCloud Drive so they're yours, not ours.

Built around great typography
New York for titles, San Francisco for chrome, your choice of font and theme for the page itself. Sepia, light, dark and true black. Margins, line spacing, paragraph gaps — all tunable.

Privacy
The cloud AI is accessed with your own Anthropic API key, which lives in your Keychain. Cloud transformations send the source text to the Anthropic API only when you confirm the run, and only for the duration of that request. Local transformations stay on your device. Nothing is uploaded to BookApp.

Supported formats
EPUB and PDF, native. MOBI on the roadmap.

BookApp is free. No subscription, no in-app purchases, no ads, no telemetry. Cloud transformations are optional and use your own Anthropic API key, billed directly by Anthropic.
```

(~2,300 chars — well under limit)

## Keywords (100 chars, comma-separated, no spaces)

```
epub,ebook,reader,audiobook,tts,speed-reading,summary,books,flashcard,compress,book-notes,transform
```

(99 chars)

## Support URL

`https://github.com/lukataylo/book-app`

## Marketing URL

`https://github.com/lukataylo/book-app`

## Privacy Policy URL

`https://github.com/lukataylo/book-app/blob/main/AppStore/privacy.md`

## Category

- Primary: **Books**
- Secondary: **Productivity**

## Age rating

**4+** — no objectionable content. (Note: book content itself is user-supplied; the app does not generate or host adult material. The transformation features include user-controlled tone modulation but the model providers' safety guidelines apply.)

## Pricing

**Free.** No in-app purchases, no subscriptions, no ads.

All core features (the bundled summaries, reader, on-device TTS, speed reading, key-learnings extraction, spaced-repetition review, and on-device AI transformations on supported hardware) are free and require no payment and no key. Optional cloud transformations use the user's own Anthropic API key and are billed directly by Anthropic — the app never marks up or collects any cloud cost.

## What's New (4000 chars per version)

Initial release.

```
Hello.
- Library: import epub or pdf from iCloud Drive, group by category.
- Reader: clean reflowable text, font / margin / theme controls.
- Listen: on-device TTS with word-level highlighting.
- Speed read: three modes from 150 to 1,200 wpm.
- Transform: compress, expand, re-style, omit themes.
- Learnings: extract, edit, export.
- Sync: every book and every transformation across all your Apple devices.
```

## Screenshots brief

The reviewer needs five screenshots per device (iPhone 6.7" required, iPhone
6.1" optional, iPad 12.9" if iPad supported). Suggested order:

1. **Library home** — empty-state version is cleanest. Title "Sharpen your mind with great books." commands the screen.
2. **Library with books** — three filled shelves: "Top selections", "Self-improvement", "Philosophy".
3. **Reader** — Chapter 1 of *The Psychopathology of Everyday Things* in serif, sepia theme, bottom bar visible.
4. **Transformation Studio** — the AI panel mid-run, showing "Compressing → 28 pages, ~$0.42" and the cost preview.
5. **Speed reader** — RSVP mode, single bold word at the optical pivot.

Caption typography: New York Bold, 56pt, off-white on the cream background, single sentence each:

1. *Your shelf, ready when you are.*
2. *Sorted automatically by category.*
3. *Read like Apple Books — your way.*
4. *Reshape any book to your schedule.*
5. *Read at the speed of thought.*

Avoid screenshots that show dummy text — use real public-domain Project
Gutenberg content (e.g. *Pride and Prejudice*, *Walden*, *Meditations*).

## In-app purchase

None. The app is free with no in-app purchases. (A future "BookApp+" tier is only an idea and is not part of this submission.)

## Review notes (private to App Review)

```
SUMMARY
BookApp is a free personal reading tool. There is no backend and we host
nothing. Most features run entirely on-device; advanced book
transformations can optionally run in the cloud via the user's own
Anthropic API key.

CORE FEATURES WORK WITH NO KEY — PLEASE TEST THESE FIRST
The app is fully usable with no API key and no payment. Without entering
any key the reviewer can:
  - Read the 80 bundled book summaries.
  - Use the reader (EPUB/PDF import, fonts, themes, margins).
  - Use on-device text-to-speech with word-level highlighting.
  - Use the spaced-repetition review of saved knowledge cards and key
    learnings.
  - Use speed-reading (paragraph/word, single-word, RSVP modes).
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
BookApp is not a generic summary catalogue. It is a full reading
environment with capabilities not offered by apps such as Blinkist or
Headway:
  - Import and read the user's own EPUB and PDF files.
  - Word-level highlighting synced to on-device text-to-speech.
  - Spaced-repetition review built from extracted learnings and cards.
  - On-device AI transformations (compress / expand / re-style) that run
    locally on supported hardware with no cloud round-trip.

CONTENT
The app does not generate or host adult content. User-imported books are
the user's own files and outside our scope.
```
