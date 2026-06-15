# Independent Pre-Submission Review

_Fresh, adversarial audit at HEAD `98e510f` by an independent reviewer (did not write the code). Read-only._

## Verdict: GO to upload — the risk is conditional approval, not technical

No technical submission blockers, no crash/2.1 issues found. The previously-claimed config fixes are **real and verified**, and the riskiest polish-pass change (covers trusting `artSlug` without an existence probe) is **provably safe**.

### Verified fixed / safe
- `ITSAppUsesNonExemptEncryption=false` present; privacy manifest declares File Timestamp (`C617.1`, used by `MetricsLog`) + UserDefaults (`CA92.1`) — neither under- nor over-declared. Entitlements clean; AppIcon + AccentColor valid.
- **Covers:** every slug a loader can set (80 packs + 3 seeds) has a matching `cover-*` asset → no path to a blank cover. Imported user books correctly fall through.
- **artSlug backfill:** v2 key bump + content-by-title guard → upgraders get covers, no duplicate books/variants. `CoverArtBackfill` independently flag-guarded.
- **Daily Review:** enrolled cards reveal a hidden answer (`front != back`); save↔review connected; lazy session creation; `registerStreakActivity` fires exactly once per session. Schema: all 14 `@Model`s registered in both blocks.
- **Notifications:** auth requested before scheduling; toggle resets to off if denied.
- **Background audio / no accounts / no private API:** all clean.

### New findings (should-fix, none blocking)
| Sev | Item | File |
|---|---|---|
| Medium | **Reset leaks on-disk files** — `resetAllContent` deletes rows but `BookStore` has no delete API, so `<uuid>/cover.jpg`, `variant-*.txt`, `images/` blobs leak forever across resets (iCloud quota) | `SettingsView.swift:249`, `BookStore.swift` |
| Low-Med | **`again` requeue unbounded** — a card you keep failing loops indefinitely in-session (leech suspend doesn't remove it from the captured queue) | `ReviewSessionView.swift:290` |
| Medium | **Dynamic Type incomplete** — `ReaderView` still has ~25 hardcoded `.font(.system(size:))` chrome labels (reading body is user-controlled, fine) | `ReaderView.swift` |
| Low | Notification permission not re-checked on Settings appear (toggle drifts ON if revoked in iOS Settings) | `SettingsView.swift` |
| Low | Unguarded `print()` in Release in the loaders | `SummaryPackLoader.swift:52,190`, `SeedBooksLoader.swift:181,185,207,210` |
| Medium (pre-existing) | Multi-device first-launch seed duplication (per-device UserDefaults guards) | `SummaryPackLoader.swift` |

### Must-do before Submit (non-code)
1. **Provide a reviewer Anthropic API key + App Review note** — Cloud transformations + teach-back need a key; core app (summaries, reader, daily review on saved cards) works without one (4.2 satisfied).
2. **Accept/prepare for the Guideline 5.2 IP risk** (the dominant approval risk — see content-legal-review.md).
3. Confirm App Store Connect externals: screenshots, reachable Privacy Policy + Support URLs (currently a GitHub blob + `mailto:`), production CloudKit container + App Group.
