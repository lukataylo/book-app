# Detailed setup

Everything you need from a fresh checkout to running on a real device.

## Prerequisites

- macOS 15+ with Xcode 26+ installed.
- An Apple Developer account (free or paid). Free works for simulator and
  on-device testing; paid is required for App Store submission, CloudKit
  sync, and distributing to other people.
- An [Anthropic API key](https://console.anthropic.com/) for cloud
  transformations. The on-device features (reader, TTS, speed reading,
  key-learnings extraction on Apple Intelligence devices) work without one.

## One-time setup

```bash
# 1. Install xcodegen (used to generate the .xcodeproj from project.yml).
brew install xcodegen

# 2. Generate the Xcode project.
cd /Users/lukadadiani/Documents/book-app
xcodegen generate

# 3. Open in Xcode.
open BookApp.xcodeproj
```

In Xcode:

1. Select the **BookApp** target.
2. Under *Signing & Capabilities*, set **Team** to your Apple Developer
   account. Change the bundle ID under *General → Identity* to something
   unique (e.g. `com.<yourname>.bookapp`).
3. Make sure these capabilities are listed:
   - **iCloud** with **CloudKit** and **iCloud Documents** turned on
   - **Background Modes** with **Audio, AirPlay, and Picture in Picture**
4. Add an iCloud container under the iCloud capability —
   `iCloud.<your-bundle-id>` — and update `project.yml` and `Info.plist`
   to match if you changed the bundle id.

## First launch

1. Build and run on **iPhone 17 Pro** simulator (default scheme) or a real
   device.
2. The Library home is empty. Tap the orange **+** in the top right (or
   the **Import a book** button on the empty state).
3. Pick an EPUB or PDF from iCloud Drive. Try a Project Gutenberg book if
   you don't have one to hand:
   <https://www.gutenberg.org/cache/epub/1342/pg1342.epub>
   (Pride and Prejudice).
4. The book appears in your shelf. Auto-tagging runs in the background;
   categories appear within a second or two on Apple Intelligence devices.
5. Tap the book to open the reader. Use the bottom-bar buttons:
   - **Read** — current view.
   - **Listen** — TTS with word-level highlighting.
   - **Speed** — three speed-reading modes.
   - **Theme** — font / margin / theme.
   - **AI** — Transformation Studio.
6. To run a cloud transformation, open *Settings → AI* and paste your
   Anthropic API key. It's stored in the iOS Keychain; nothing is written
   to disk in plain text and nothing is committed to git.

## Regenerating the icon

```bash
python3 scripts/generate-icon.py
```

Edit the script if you want to adjust the palette or the mark.

## Local LLM

The app tries Apple Foundation Models first
(`SystemLanguageModel.default.availability == .available`). If that's not
available — older iPhones, Intel Macs — the router falls back to MLX-Swift
if you've opted into it.

To opt in:

1. Run `xcodebuild -downloadComponent MetalToolchain` once.
2. Uncomment the `MLXSwift` package + dependency in `project.yml`.
3. Re-run `xcodegen generate`.

Without MLX and without Apple Foundation Models, every task that the
router would have routed locally falls through to the cloud (Claude). It
still works; you'll just see slightly higher cloud cost on the things
that would normally have been free.

## Tests

```bash
xcodebuild test \
  -project BookApp.xcodeproj \
  -scheme BookApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

There are unit tests for the chunker and prompt templates. Test target
uses Swift Testing (the modern `@Test` macros, not XCTest).

## Troubleshooting

**"CloudKit integration does not support unique constraints"** — should
not happen any more. If it does, look for `@Attribute(.unique)` lurking
in any new model.

**Reader is empty after import** — your EPUB might have a non-standard
spine (Apple Books exports sometimes do this). Check that the Files app
shows the file under `<iCloud>/BookApp/<bookID>/original.epub`.

**Transformation Studio says "missing API key"** — paste your key in
*Settings → AI*. It's in your Keychain so you only do this once per
device.

**Build fails for native macOS** — the Readium SwiftPM platform setup
clashes with macOS deployment targets. Use Mac Catalyst (Designed for
iPad) — see `project.yml` comments for re-enabling steps.
