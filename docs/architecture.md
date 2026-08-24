# Architecture

BookApp is a single SwiftUI codebase targeting iOS 18+ and iPadOS 18+.
Everything runs locally; the only thing that touches the network is the
optional Anthropic API call when you explicitly choose a cloud
transformation. There is no BookApp server.

The catalog ships two things per title: the public-domain work itself
(`Resources/FullTexts/<slug>.txt`, fetched once by
`scripts/fetch-full-texts.py`) and an original summary of it
(`Resources/SummaryPacks/<slug>.json`). `SummaryPackLoader` seeds the
work as the book's `.original` variant and the summary as a
`.compressed` one beside it, so the reader, TTS, chapter list, search and
the Transformation Studio all operate on both without knowing the
difference.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BookApp (SwiftUI)                           │
│                                                                     │
│  ┌─────────────┐ ┌─────────────┐ ┌──────────┐ ┌─────────┐ ┌──────┐  │
│  │   Library   │ │   Reader    │ │   TTS    │ │  Speed  │ │  AI  │  │
│  │   ─────     │ │   ─────     │ │  ─────   │ │  Reader │ │ ──── │  │
│  │ shelves +   │ │ font /      │ │ word-    │ │ inline  │ │ comp │  │
│  │ search +    │ │ margin /    │ │ level    │ │ 150-    │ │ exp  │  │
│  │ import      │ │ theme       │ │ highlight│ │ 1200wpm │ │ style│  │
│  │             │ │ controls    │ │          │ │         │ │ omit │  │
│  └─────────────┘ └─────────────┘ └──────────┘ └─────────┘ └──────┘  │
│         │              │             │             │          │     │
│         └──────────────┴─────────────┴─────────────┴──────────┘     │
│                            │                                        │
│  ┌─────────────────────────┴──────────────────────────────────┐     │
│  │ Services                                                    │    │
│  │                                                             │    │
│  │  BookParser  →  EPUB (ZIPFoundation)                        │    │
│  │              →  PDF  (PDFKit)                               │    │
│  │                                                             │    │
│  │  LLMRouter   →  LocalProvider  (Apple FoundationModels)      │    │
│  │              →  ClaudeProvider (Anthropic Messages API)     │    │
│  │                                                             │    │
│  │  Storage     →  iCloud Drive (book files + variants)        │    │
│  │              →  SwiftData + CloudKit (metadata)             │    │
│  │                                                             │    │
│  │  Keychain    →  Anthropic API key                           │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘

                        ┌──────────────────────┐
                        │ User's iCloud account │
                        ├──────────────────────┤
                        │ • iCloud Drive        │  binaries
                        │ • Private CloudKit DB │  metadata
                        └──────────────────────┘
                                     ▲
                                     │ sync
                                     │
                        ┌──────────────────────┐
                        │  Other Apple devices │
                        └──────────────────────┘

                        ┌──────────────────────┐
                        │  api.anthropic.com   │  cloud transforms only,
                        ├──────────────────────┤  with the user's own key
                        │  Claude 4.x          │  and explicit confirmation
                        └──────────────────────┘
```

## Layered modules

### `App/`

`BookAppApp` constructs the model container and seeds the root scene.
`RootTabView` hosts four tabs: Read, Search, Saved, Settings.

### `Models/`

Eight `@Model` classes, all CloudKit-compatible:

- `Book`, `BookVariant`, `Annotation`, `Bookmark`, `ReadingProgress`
- `ReaderSettings`, `TTSSettings`, `SpeedReaderSettings`

Body text and cover bytes never live in a row — they go to disk under
`<bookFolder>` (`BookVariant.writeText` / `BookStore.writeCover`),
because CloudKit stalls or silently drops multi-megabyte fields.

Every property is optional or has a default. We don't use `@Attribute(.unique)` because CloudKit-private databases reject unique constraints — uniqueness is enforced by construction (UUIDs).

See [docs/data-model.md](data-model.md) for the schema.

### `Services/`

#### `BookParser/`

`PDFParser` uses PDFKit. `EPUBParser` parses the EPUB ZIP container, OPF
manifest and spine in-house using `ReadiumZIPFoundation` for ZIP reads, and
`XMLParser` for the OPF + container.xml.

Two formats, both of which work. MOBI was declared in `Info.plist` and
advertised in the listing while `MOBIConverter` always threw — so iOS
offered the app as a handler for `.mobi` and it failed every time. The
converter and the UTIs are gone; users convert with Calibre first.

#### `Privacy/`

`CloudConsent` holds one flag, and `ClaudeProvider` refuses to be
available without it. Guideline 5.1.2(i) requires named consent before
user content reaches a third-party AI, and enforcing that at the network
boundary rather than the call sites is what makes it hold: the router
skips an unavailable provider exactly as it skips a device with no Apple
Intelligence, so no feature can transmit by forgetting to ask.

#### `LLM/`

The most interesting module.

- `LLMRouter` is the only place that knows about provider availability.
  Every caller hands it a task; the router picks the best provider, falls
  back if needed, returns a finished `LLMResponse`.
- `LocalProvider` runs Apple Foundation Models. On hardware without
  Apple Intelligence it reports unavailable and the router falls through
  to the cloud.
- `ClaudeProvider` is a thin URLSession wrapper around the Anthropic
  Messages API. Source text is sent as a system block with
  `cache_control: ephemeral` so subsequent transforms of the same book pay
  ~10% of the input-token price within the 5-minute cache TTL.
- `Chunker` does token-aware map-reduce: splits on chapter markers, packs
  blocks into chunks under the budget, hard-windows oversized blocks, and
  carries `overlapTokens` of context across chunk boundaries.
- `PromptTemplates` is the one place every transformation prompt lives.

See [docs/llm-routing.md](llm-routing.md).

#### `Storage/`

`BookStore` owns the iCloud Drive container (`iCloud.com.lukataylor.bookapp`).
Books and transformations are stored as files there; metadata stays in
CloudKit. This keeps the CloudKit quota tiny while still giving you a
shareable Files-app folder.

#### `Keychain/`

`KeychainStore` is a 60-line wrapper around `Security.framework`. Only
ever stores the Anthropic API key.

### `Features/`

One folder per feature, each with views + view-model + the engine that
talks to services.

- `Library/` — home shelf, category groups, book cards.
- `Import/` — document picker + the end-to-end import pipeline.
- `Reader/` — reflowable reader, settings sheet, and the inline Speed and
  Listen modes.
- `TTS/` — playback engine + voice picker.
- `Saved/` — the highlights + bookmarks gallery.
- `Search/` — one field spanning books and saved passages.
- `Transformations/` — TransformationStudio + map-reduce engine + cost
  estimate.
- `Settings/` — API key, monthly spend, privacy notice.

### `Design/`

`Theme` (palette + spacing + radii + book-spine colors) and `Typography`
(serif tokens for titles, SF Pro for chrome).

## Concurrency

Swift 6 strict concurrency, complete checking.

- `LLMRouter`, `LocalProvider`, `ClaudeProvider` are actors.
- Engines (Transformation, Import, TTS) are `@MainActor` — they
  only ever run on the main queue, which keeps them free of cross-actor
  hops when reading SwiftData models.
- The EPUB parser uses an internal `DataCollector` actor to accumulate
  ZIP-extract chunks safely.
- Delegate methods that come from non-isolated callbacks
  (`AVSpeechSynthesizerDelegate`) are marked `nonisolated` and dispatch
  back to the main actor via `Task { @MainActor in ... }`.

## Persistence + sync

`NSPersistentCloudKitContainer`-style: `ModelConfiguration` with
`cloudKitDatabase: .private("iCloud.com.lukataylor.bookapp")`. SwiftData
handles the round-trip. The simulator without an iCloud account
gracefully falls back to in-memory.

Book binaries and variant outputs are stored under
`<iCloud Drive>/BookApp/<bookID>/` so they appear in the Files app and
can be inspected/edited externally if needed.

## Privacy posture

- **No analytics. No telemetry. No backend.**
- Local-first: everything that can run on-device does.
- Cloud transformations require explicit per-run confirmation.
- API key in Keychain, never in source, never sent anywhere except
  `api.anthropic.com`.

See [AppStore/privacy.md](../AppStore/privacy.md) for the user-facing version.
