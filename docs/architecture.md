# Architecture

BookApp is a single SwiftUI codebase targeting iOS 18+ and iPadOS 18+.
Everything runs locally; the only thing that touches the network is the
optional Anthropic API call when you explicitly choose a cloud
transformation. There is no BookApp server.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BookApp (SwiftUI)                           │
│                                                                     │
│  ┌─────────────┐ ┌─────────────┐ ┌──────────┐ ┌─────────┐ ┌──────┐  │
│  │   Library   │ │   Reader    │ │   TTS    │ │  Speed  │ │  AI  │  │
│  │   ─────     │ │   ─────     │ │  ─────   │ │  Reader │ │ ──── │  │
│  │ shelves +   │ │ font /      │ │ word-    │ │  3      │ │ comp │  │
│  │ search +    │ │ margin /    │ │ level    │ │ modes   │ │ exp  │  │
│  │ import      │ │ theme       │ │ highlight│ │ 150-    │ │ style│  │
│  │             │ │ controls    │ │          │ │ 1200wpm │ │ omit │  │
│  └─────────────┘ └─────────────┘ └──────────┘ └─────────┘ └──────┘  │
│         │              │             │             │          │     │
│         └──────────────┴─────────────┴─────────────┴──────────┘     │
│                            │                                        │
│  ┌─────────────────────────┴──────────────────────────────────┐     │
│  │ Services                                                    │    │
│  │                                                             │    │
│  │  BookParser  →  EPUB (ZIPFoundation)                        │    │
│  │              →  PDF  (PDFKit)                               │    │
│  │              →  MOBI (libmobi, planned)                     │    │
│  │                                                             │    │
│  │  LLMRouter   →  LocalProvider  (FoundationModels / MLX)     │    │
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
`RootTabView` hosts four tabs: Library, Search, Learnings, Settings.

### `Models/`

Eight `@Model` classes, all CloudKit-compatible:

- `Book`, `BookVariant`, `KeyLearning`, `Annotation`, `ReadingProgress`
- `ReaderSettings`, `TTSSettings`, `SpeedReaderSettings`

Every property is optional or has a default. We don't use `@Attribute(.unique)` because CloudKit-private databases reject unique constraints — uniqueness is enforced by construction (UUIDs).

See [docs/data-model.md](data-model.md) for the schema.

### `Services/`

#### `BookParser/`

`PDFParser` uses PDFKit. `EPUBParser` parses the EPUB ZIP container, OPF
manifest and spine in-house using `ReadiumZIPFoundation` (transitively
pulled in by Readium) for ZIP reads, and `XMLParser` for the OPF +
container.xml. `MOBIConverter` is a stub — full conversion needs `libmobi`
wired in as a C target; for now it surfaces a friendly "convert with Calibre"
error.

#### `LLM/`

The most interesting module.

- `LLMRouter` is the only place that knows about provider availability.
  Every caller hands it a task; the router picks the best provider, falls
  back if needed, returns a finished `LLMResponse`.
- `LocalProvider` tries Apple Foundation Models first, falls back to MLX
  on hardware where Apple Intelligence isn't available.
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
- `Reader/` — paginated reflowable reader + settings sheet.
- `TTS/` — playback engine + voice picker.
- `SpeedReading/` — three modes, WPM control.
- `Transformations/` — TransformationStudio + map-reduce engine + cost
  estimate.
- `KeyLearnings/` — extraction + per-book + global lists + export.
- `Settings/` — API key, monthly spend, privacy notice.

### `Design/`

`Theme` (palette + spacing + radii + book-spine colors) and `Typography`
(serif tokens for titles, SF Pro for chrome).

## Concurrency

Swift 6 strict concurrency, complete checking.

- `LLMRouter`, `LocalProvider`, `ClaudeProvider` are actors.
- Engines (Transformation, Extraction, Import, TTS) are `@MainActor` — they
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
