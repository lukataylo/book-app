# Data model

Eight `@Model` classes. Every property is optional or has a default
(CloudKit's private-database integration rejects schemas with required
properties or unique constraints). Uniqueness is enforced at the
application layer using UUIDs.

## Diagram

```
                      ┌───────────────────┐
                      │      Book         │
                      │ id, title, author │
                      │ format, hasCover  │
                      │ categoryTags      │
                      │ detectedThemes    │
                      └─────────┬─────────┘
                                │
        ┌──────────────┬────────┴────────┬───────────────┐
        ▼              ▼                 ▼               ▼
  ┌───────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐
  │BookVariant│  │  Annotation │  │  Bookmark   │  │ReadingProg│
  │ kind      │  │ locator     │  │ paragraph   │  │ percent   │
  │ targetPgs │  │ note, color │  │ label       │  │ locator   │
  │ style     │  │ quotedText  │  │ snippet     │  │           │
  │ omitted   │  │             │  │             │  │           │
  │ cost      │  │             │  │             │  │           │
  └───────────┘  └─────────────┘  └─────────────┘  └───────────┘

  Body text and cover bytes are NOT columns. They live on disk at
  `<bookFolder>/variant-<id>.txt` and `<bookFolder>/cover.jpg` —
  CloudKit stalls or silently drops multi-megabyte fields.

                  Singletons (one row per device, synced)
                  ┌──────────────┐ ┌──────────────┐ ┌────────────────┐
                  │ReaderSettings│ │ TTSSettings  │ │SpeedReaderSettings│
                  └──────────────┘ └──────────────┘ └────────────────┘
```

## Tables

### `Book`

| field | type | notes |
|---|---|---|
| id | UUID | logical id |
| title, author | String | from parser |
| hasCoverImage | Bool | true once a jpeg is at `BookStore.coverURL(bookID:)` |
| formatRaw | String | enum-backed: epub / pdf / mobi |
| originalFileBookmark | Data? | secure URL bookmark to the original file in iCloud Drive |
| totalPagesEstimate | Int | ~250 wpw heuristic |
| categoryTags | [String] | LLM-derived on import |
| detectedThemes | [String] | LLM-derived on import |
| importedAt, lastOpenedAt | Date | sort keys |

### `BookVariant`

A pluggable rendition of a book. Every Book has at least the `.original`
variant. Compressed / expanded / styled / theme-omitted variants are
generated on demand.

| field | type | notes |
|---|---|---|
| kind | enum | original / compressed / expanded / styled / themeOmitted |
| — | — | the body is **not** a column: `writeText` / `loadText` go to `<bookFolder>/variant-<id>.txt` |
| targetPages | Int | what the user asked for |
| styleReference | String | the requested voice, e.g. "spare and literary" |
| omittedThemes | [String] | for theme-omission |
| modelUsed | String | Claude / Apple FM |
| inputTokens, outputTokens, cachedInputTokens, costUSD | Int / Double | recorded from the API response so monthly spend in Settings is exact, not estimated |

### `Bookmark`

| field | type | notes |
|---|---|---|
| variantID | UUID? | which rendition the marker was dropped in |
| paragraphIndex | Int | position within that variant |
| label | String | optional; falls back to the paragraph's first sentence |
| snippet | String | captured at bookmark time so lists don't load the body |

### `Annotation`

| field | type |
|---|---|
| locator | String (opaque) |
| quotedText | String |
| note | String |
| colorRaw | enum (yellow / green / blue / pink / purple) |

### `ReadingProgress`

| field | type |
|---|---|
| variantID | UUID — which variant |
| locator | String (opaque) |
| percent | 0–1 |
| currentPage, totalPages | Int |

### Settings models

`ReaderSettings`, `TTSSettings`, `SpeedReaderSettings` are de-facto
singletons. Each has one row per user, synced through CloudKit so your
typography preferences follow you across devices.

## Why no unique constraints

`@Attribute(.unique)` is the natural way to declare uniqueness in
SwiftData. **CloudKit's private-database integration rejects it.**
We tried it; the store fails to load with `loadIssueModelContainer`.
The fix: drop the constraints, generate UUIDs in the model `init` so
collisions are statistically impossible, and rely on
`@Relationship(inverse:)` to keep cross-references clean.

## Storage layout

```
iCloud Drive/
└── BookApp/
    └── <bookID-uuid>/
        ├── original.epub                    (or .pdf, .mobi)
        └── variant-<variantID-uuid>.txt     (one per generated variant)
```

The book file itself — and every transformation's plaintext output —
lives in iCloud Drive, not in CloudKit. CloudKit holds only metadata
(title, locators, costs, settings). This keeps the user's CloudKit
quota basically free even for thousands of books, and makes the files
visible in the Files app.

## Conflict resolution policy

SwiftData's CloudKit backing is **last-write-wins** with no per-field
merge. We deliberately don't implement a custom merge policy. Why:

- **Annotations + Bookmarks are append-only in practice.** The user
  flow is "highlight a passage" or "mark a page" — both create a new
  row. Edits to existing rows are rare (changing a highlight's note
  or color). Last-write-wins on these fields is acceptable: whichever
  device touched the row most recently wins, which matches user
  intuition.
- **ReadingProgress is correctly last-write-wins.** "Where did I leave
  off?" is a question about the most recent state, not a merge of
  positions. CloudKit's sync delay (~30s) means rapid two-device
  switching may briefly show the other device's older position; the
  next progress write reconciles.
- **Settings (Reader/TTS/Speed) are de-facto singletons.** Same logic
  as ReadingProgress.
- **BookVariant.contentText** is set once at generation and never
  edited. Conflicts impossible.
- **Book.title / .author** can be edited via "Edit metadata" sheet.
  Two-device concurrent edits to these would lose data, but this is
  not a frequent flow and we accept the risk for v1.

`Annotation.lastEditedAt` is recorded so a future "show conflicting
edits" UI (or a manual reconciliation tool) has a reliable ordering
signal. Today nothing reads it; the field is forward-compatibility
for v1.1.

If a user reports lost annotations after multi-device editing, we
have two escalation paths:
1. Bump SwiftData's `mergePolicy` to a property-trump variant.
2. Snapshot annotations to JSON in the iCloud Drive folder so a
   user-visible recovery file exists.
