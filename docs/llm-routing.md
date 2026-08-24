# LLM routing

`LLMRouter` is the only component that decides whether a task runs
locally or in the cloud, and which model it picks. Callers —
`TransformationEngine` and `ImportService` — hand it a task and get back
an `LLMResponse`. The router keeps a fallback chain per task type, tries
each provider in order, and returns the first successful result.

## Routing table

| Task | Default chain | Notes |
|---|---|---|
| Auto-tag categories | Apple FM → Haiku 4.5 | Runs in background after import. Cheap. |
| Short summary | Apple FM → Haiku 4.5 | Stays on-device whenever possible. |
| Compression | Apple FM → Sonnet 5 → Opus 5 | Local first. User can re-run with cloud if unhappy. |
| Expansion ≥3× | Apple FM → Opus 5 → Sonnet 5 | Opus produces noticeably better long-form expansion. |
| Expansion <3× | Apple FM → Sonnet 5 → Opus 5 | |
| Style transfer | Apple FM → Opus 5 → Sonnet 5 | Hardest task. Quality matters most. |
| Theme omission | Apple FM → Sonnet 5 → Opus 5 | |
| Combined (length + style + omission) | Apple FM → Opus 5 → Sonnet 5 | |

Sonnet 5 and Opus 5 reject sampling parameters, so `ClaudeProvider` sends
no `temperature`; both run adaptive thinking by default when the
`thinking` field is absent. `temperature` still reaches the on-device
model.

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
                        ┌──────────┴──────────┐
                        ▼                     ▼
             ┌─────────────────┐   ┌──────────────────┐
             │  LocalProvider  │   │  ClaudeProvider  │
             │ Apple Foundation│   │   Anthropic API  │
             │     Models      │   │                  │
             └────────┬────────┘   └─────────┬────────┘
                      │                      │
        `SystemLanguageModel          Needs an API key
        .default.availability         in the Keychain.
        == .available`
```

A request fails over down the chain on `providerUnavailable` or
`missingAPIKey`. Other errors (network, rate-limited, decoding) bubble up
to the caller so the UI can show a meaningful message.
