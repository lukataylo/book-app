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
Have an hour, but the book takes ten? Compress it to a 20-page summary that keeps the author's voice and every key idea. Or take a five-page essay and expand it to a full chapter when you want to go deeper. Compression and expansion run on Apple's on-device intelligence when possible, and on Claude when the text is long or the task is hard — you always see the model and the cost before anything runs.

Listen, on-device
Every book becomes an audiobook with the system's premium voices. The current word lights up as it's spoken, the page flips itself, and lock-screen controls keep working in the background. No cloud round-trip; nothing leaves the device.

Speed read
Three modes — paragraph + word highlight, single-word focus, and Spritz-style RSVP — at any pace from 150 to 1,200 words per minute. Pause at punctuation, jump back a sentence, hand it off to TTS when you've found a passage worth hearing.

Re-style
Make a dense academic chapter sound more like Malcolm Gladwell. Strip every reference to a theme you're not interested in. Try a single chapter as a different voice before committing to the whole book.

Key learnings
Pull 5 to 15 key learnings from any book in seconds. Edit, star, export to Markdown or JSON. Quiz yourself with auto-generated flashcards.

Your library, in iCloud
Your shelf, your reading position, your annotations, your transformations — all sync across iPhone, iPad and Mac. Books live in your iCloud Drive so they're yours, not ours.

Built around great typography
New York for titles, San Francisco for chrome, your choice of font and theme for the page itself. Sepia, light, dark and true black. Margins, line spacing, paragraph gaps — all tunable.

Privacy
The Anthropic API key is yours and lives in your Keychain. Cloud transformations send the source text to Anthropic only when you confirm the run, and only for the duration of that request. Local transformations stay on your device. Nothing is uploaded to BookApp.

Supported formats
EPUB and PDF, native. MOBI on the roadmap.

BookApp is one-time purchase. No subscription, no ads, no telemetry.
```

(2,212 chars — well under limit)

## Keywords (100 chars, comma-separated, no spaces)

```
epub,ebook,reader,audiobook,tts,speed-reading,summary,ai,claude,books,reading,annotations,kindle
```

(98 chars)

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

One-time purchase. Suggested tier: **$9.99** (Tier 10).

The Anthropic API usage is paid by the user via their own API key — the app never marks up cloud costs, and the local model is free.

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

None for v1. Future "BookApp+" tier could add multi-device cloud key sharing.

## Review notes (private to App Review)

```
This app is a personal reading tool that uses on-device intelligence and
the user's own Anthropic API key for advanced book transformations. No
backend; we host nothing. Cloud transformations require the user to
explicitly confirm the run and to enter their own API key in Settings.

Test account: not required. To test cloud transformations the reviewer
would need to add a temporary key in Settings → AI; we will provide one
on request via the App Review Information.

The app does not generate or host adult content. User-imported books are
out of our scope.
```
