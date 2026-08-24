<div align="center">

<img src="BookApp/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png" width="120" alt="Epigrapha" />

# Epigrapha

**Books that bend to your time.**

28 public-domain classics in full, each with a 5-minute summary and a 2-minute quick take.
Compress a 400-page book to 20. Listen on-device. Re-style any book to read like another.

<sub>iOS · iPadOS · SwiftUI · SwiftData + CloudKit · Apple Foundation Models · Claude</sub>

[Setup](#setup) · [Architecture](docs/architecture.md) · [LLM routing](docs/llm-routing.md) · [Data model](docs/data-model.md) · [Privacy](AppStore/privacy.md)

<img src="docs/screenshots/library-empty.png" width="280" alt="Library home" />

</div>

---

## What it does

Most reading apps assume you have time for the whole book. Epigrapha doesn't.

**Read · Save** — the core loop:

- **Read.** 28 public-domain works in full — Meditations, Walden, On Liberty,
  The Wealth of Nations — each paired with an original "The Big Ideas in …"
  summary (~5 min, clean-room prose with attribution) and a ~2-minute quick
  take. Pick your length on the book page. Plus everything you import yourself.
- **Save.** Highlights and extracted key learnings from every book, collected in
  one searchable tab.

And the original toolkit applies to all of it:

- **Re-style.** Rewrite a book in another voice — staged as Shakespeare, narrated
  as a nature documentary, filed as a corporate memo. Six re-styles ship
  pre-generated so the trick works on a fresh install with no API key. Voices are
  public-domain authors and genre registers only; naming a living author invites
  right-of-publicity claims.
- **Elastic length.** Compress a 400-page treatise into a 20-page summary that keeps the author's voice. Or expand a five-page essay into a chapter. The model preserves tone, structure and key arguments.
- **Listen on-device.** Every book becomes an audiobook using the best voice installed on the device. The current word lights up as it's spoken; the page flips itself.
- **Speed-read.** The current word highlighted in place at any pace from 150 to 1,200 wpm, so you keep your position in the paragraph.
- **Re-style.** Make a dense academic chapter sound more like Joan Didion. Strip references to a theme you don't care about.
- **Pull key learnings.** 5 to 15 takeaways per book in seconds. Edit, star, export.
- **Yours.** Books in your iCloud Drive. Anthropic API key in your Keychain. No backend.

## Setup

```bash
brew install xcodegen
cd /Users/lukadadiani/Documents/book-app
xcodegen generate
open BookApp.xcodeproj
```

In Xcode, set your **Team** under *Signing & Capabilities* and choose a unique
bundle id. Build and run on **iPhone 17 Pro** (or any iOS 18+ simulator).

On first launch:

1. Open *Settings → AI* and paste your Anthropic API key. It's stored in the
   iOS Keychain — never on disk in plain text, never in the project.
2. Tap **Import a book** on the home screen and pick an `.epub` or `.pdf`
   from iCloud Drive. (Other formats need converting first — Calibre does
   this for free.)

Get a Claude API key at <https://console.anthropic.com/>.

## Tech

| Layer | Choice |
|---|---|
| UI | SwiftUI on iOS 18+ / iPadOS 18+ |
| Persistence | SwiftData with private CloudKit sync |
| EPUB | In-house parser over `ReadiumZIPFoundation` |
| PDF | PDFKit |
| TTS | `AVSpeechSynthesizer` with word-range highlighting |
| Local LLM | Apple Foundation Models |
| Cloud LLM | Claude Sonnet 5 / Opus 5 via Anthropic Messages API + ephemeral prompt caching |

See [docs/architecture.md](docs/architecture.md) for the full picture.

## Topics

`ios` · `swiftui` · `ipados` · `swiftdata` · `cloudkit` · `epub-reader` ·
`pdf-reader` · `text-to-speech` · `speed-reading` · `public-domain` ·
`anthropic` · `apple-foundation-models` · `book-summarizer` · `rsvp`

## License

Personal-use license. The transformations of imported books are stored
locally and on your iCloud account; do not redistribute. The app does not
facilitate any public sharing of transformed content.
