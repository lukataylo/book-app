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

The only third party that ever receives any of your data is **Anthropic
PBC**, and only when you explicitly trigger a cloud feature with your own
Anthropic API key.

Exactly what is sent, and when:

- **Cloud transformations (Transformation Studio):** the book / source
  text you choose to transform, together with the prompt, is sent to the
  Anthropic API (`https://api.anthropic.com`).
- **Teach-back grading:** when you write an explanation to be graded and
  on-device AI is unavailable (e.g. the device does not support Apple
  Intelligence), the text you typed is sent to the Anthropic API to be
  graded. When on-device AI is available, grading stays on the device and
  nothing is sent.

In both cases the request is made under **your own Anthropic API key** and
is processed by Anthropic per their published data-handling policy:
<https://www.anthropic.com/privacy>. **BookApp does not store this data and
never receives a copy** — the request goes directly from your device to
Anthropic.

You can use BookApp without sending anything to Anthropic — every cloud
request requires explicit confirmation, and the on-device features
(reader, TTS, speed reading, spaced-repetition review, key-learnings
extraction and on-device transformations on Apple Intelligence devices)
work entirely offline. There is **no account, no sign-in, and no
tracking** of any kind.

## Calendar and Reminders

The Act tab can export a book's action plan to your device. Calendar access
is **write-only**: BookApp can add the practice sessions you ask for but can
never read your existing events. Reminders access is requested only when you
export plan to-dos. Both are optional — the in-app checklist works without
either permission — and nothing about your calendar or reminders ever leaves
your device or reaches us.

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
