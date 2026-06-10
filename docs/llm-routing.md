# LLM routing

`LLMRouter` is the only component that decides whether a task runs
locally or in the cloud, and which model it picks. Every caller —
TransformationEngine, ExtractionEngine, ImportService — just hands it a
task and gets back an `LLMResponse`. The router keeps a fallback chain
per task type, tries each provider in order, and returns the first
successful result.

## Routing table

| Task | Default chain | Notes |
|---|---|---|
| Auto-tag categories | Apple FM → MLX → Haiku 4.5 | Runs in background after import. Cheap. |
| Key-learnings extraction | Apple FM → MLX → Haiku 4.5 | Stays on-device whenever possible. |
| Quiz / flashcard generation | Apple FM → MLX → Haiku 4.5 | |
| Compression to ≥30% length, source <50K tokens | Apple FM → MLX → Sonnet 4.6 | Local first. User can re-run with cloud if unhappy. |
| Compression to <30% length, OR source ≥50K tokens | Sonnet 4.6 → Opus 4.7 | Cloud only — long compression needs the bigger context. |
| Expansion ≥3× | Opus 4.7 → Sonnet 4.6 | Opus produces noticeably better long-form expansion. |
| Expansion <3× | Sonnet 4.6 → Opus 4.7 | |
| Style transfer ("sound like Didion") | Opus 4.7 → Sonnet 4.6 | Hardest task. Quality matters most. |
| Theme omission | Sonnet 4.6 → Opus 4.7 | |
| Chat with book | Sonnet 4.6 → Haiku 4.5 | Source text is prompt-cached so follow-ups are cheap. |

## Map-reduce for long books

```
       ┌─────────────────────────────┐
       │   Source book (full text)   │
       └──────────────┬──────────────┘
                      │
                      ▼
            ┌──────────────────┐
            │      Chunker     │   chapter-aware split,
            │                  │   overlap-aware joins,
            │                  │   hard-window oversized blocks
            └────┬─────┬────┬──┘
                 │     │    │
                 ▼     ▼    ▼
              chunk1 chunk2 chunkN
                 │     │    │
            ┌────┴─────┴────┴────┐
            │   Map (per chunk)  │   PromptTemplates.transformChunk
            │   Sonnet/Opus      │   cache_control: ephemeral
            └────┬─────┬────┬────┘   (source as cached system block)
                 │     │    │
                 ▼     ▼    ▼
              out1   out2  outN
                 │     │    │
                 └─┬───┴────┘
                   ▼
            ┌──────────────────┐
            │  Reduce (seam)   │   PromptTemplates.seamRewrite
            │  rewrites every  │   makes outN+1 flow from outN
            │  chunk boundary  │
            └────────┬─────────┘
                     ▼
            ┌──────────────────┐
            │   Final output   │   persisted as BookVariant
            └──────────────────┘
```

### Caching

Anthropic prompt caching makes this affordable. The source-text block is
sent with `cache_control: { "type": "ephemeral" }` and is reused across
every map call within the 5-minute TTL — input cost on the cached block
drops to ~10% after the first hit. Two transforms of the same book
back-to-back cost barely more than one.

### Cost telemetry

Every call records:

- input tokens (uncached)
- input tokens (cached read)
- output tokens
- USD cost

Costs are read off the API response itself, not estimated, so the
"Spend this month" number in Settings is exact. Estimates shown in the
TransformationStudio _before_ a run use list prices for the chosen model.

## Provider availability

```
                      ┌────────────────────────┐
                      │    LLMRouter.run()     │
                      └────────────┬───────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
   ┌─────────────────┐  ┌────────────────────┐  ┌──────────────────┐
   │  LocalProvider  │  │  LocalProvider     │  │ ClaudeProvider   │
   │  Apple Foundation│  │  MLX (arm64 only) │  │  Anthropic API   │
   │  Models          │  │  (canImport gate) │  │                  │
   └────────┬─────────┘  └─────────┬─────────┘  └─────────┬────────┘
            │                      │                       │
   `SystemLanguageModel    Optional package, off    Needs API key in
   .default.availability   by default — opt in      Keychain.
   == .available`          via the build flag
                           in project.yml
```

A request fails over down the chain on `providerUnavailable` or
`missingAPIKey`. Other errors (network, rate-limited, decoding) bubble up
to the caller so the UI can show a meaningful message.
