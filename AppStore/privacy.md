# Privacy Policy

*Last updated: 2026-05-05*

BookApp is a single-developer app that runs entirely on your device and in
your iCloud account. There is no BookApp server.

## What we don't collect

We do not collect, store, transmit, sell or share any personal information.
We do not run analytics. We do not have a backend.

## What stays on your device

- Book files you import (EPUB / PDF)
- Generated transformations (compressed, expanded, re-styled variants)
- Annotations, highlights, key learnings, reading progress
- Reader / TTS / speed-reader settings
- Your Anthropic API key — stored in the iOS Keychain, **never written to
  disk in plain text and never sent to any server other than Anthropic's API
  endpoint when you initiate a cloud transformation**.

## What syncs to iCloud

When you are signed into iCloud, the metadata for the items above (but not
the API key) syncs to your **private** CloudKit database, accessible only
by you and only on your Apple devices signed into the same Apple Account.
We do not have, and cannot get, access to this data.

## What goes to Anthropic

When you explicitly choose to run a cloud transformation in the
Transformation Studio, the source text and the prompt are sent to
Anthropic's API endpoint (`https://api.anthropic.com`) under your own
Anthropic API key. The data is processed by Anthropic per their published
data-handling policy: <https://www.anthropic.com/privacy>. BookApp never
receives a copy.

You can use BookApp without sending anything to Anthropic — every cloud
transformation requires explicit confirmation, and the on-device features
(reader, TTS, speed reading, key-learnings extraction on Apple Intelligence
devices) work entirely offline.

## Audiobook playback (TTS)

Text-to-speech uses Apple's `AVSpeechSynthesizer`. Voices run on-device.
Premium voices are downloaded directly from Apple, not BookApp. No audio
data leaves your device.

## Children

BookApp is rated 4+. We do not knowingly collect any data from anyone of
any age, because we do not collect data.

## Contact

Questions about this policy: please open an issue at
<https://github.com/lukataylo/book-app/issues>.
