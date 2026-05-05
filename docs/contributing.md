# Contributing

This started as a personal project. Pull requests and issues welcome.

## Style

- **Swift 6, strict concurrency.** New code must compile cleanly with
  `SWIFT_STRICT_CONCURRENCY=complete`.
- **No comments that explain what code does** — only why something
  non-obvious is the way it is.
- **No abstractions for hypothetical future requirements.**
- **One-shot operations don't need helpers.** Prefer three similar lines
  to a premature helper.

## Project rules

- Don't add `@Attribute(.unique)` to any `@Model` — CloudKit rejects it.
- Don't introduce a new ModelContainer somewhere downstream; route all
  persistence through the existing `@Environment(\.modelContext)`.
- Long-running async work uses `Task { ... }` on the appropriate actor,
  not `Task.detached` unless there's a documented reason.
- Cloud transformations always go through `LLMRouter`. Don't call
  `ClaudeProvider` directly from a feature module.

## Layout

See [architecture.md](architecture.md). New features land under
`Features/<FeatureName>/` with their own engine + view-models. Cross-cutting
infrastructure goes in `Services/`.

## Tests

Use Swift Testing (`@Test`, `#expect`). `Chunker` and `PromptTemplates`
already have tests. New parsing logic should have tests.

## Commit messages

Imperative mood, short, focused. Example: `add seam-rewrite pass to
TransformationEngine`.

## Releases

See [AppStore/release-checklist.md](../AppStore/release-checklist.md).
