# App Store Rejection Pre-emption — Mitigations

_Synthesis of three independent web-research passes (Dec 2025–Jun 2026 rejections for book/IP apps, AI apps, and technical/privacy + "AI-generated code" tells), cross-referenced to this codebase. Severity = likelihood × impact of an Apple rejection. Sources in the agent transcripts._

## BLOCKERS — fix before submitting

1. **5.1.2(i) — explicit consent before sending text to a third-party AI.** Apple's Nov 13 2025 rule requires a named, pre-transmission consent gate (Allow/Cancel) before any personal data goes to a third-party AI. Real rejections cite this verbatim. Today `TransformationStudioView.startRun()` calls the cloud with **no consent dialog**, and `SettingsView` copy even *claims* "every cloud run needs an explicit confirmation" — which doesn't exist (also a 2.3.1 inconsistency).
   → **Code:** add a one-time consent sheet (persisted) before the first cloud transform, naming **Anthropic** and the data sent; make the same gate cover **teach-back** (it also falls through to Claude when Apple Intelligence is absent — see #4). Fix the false Settings line.
2. **Privacy Nutrition Label must declare "User Content → Anthropic."** The label currently implies no data collection; cloud transforms send book text. App Review cross-checks the label against network behavior.
   → **App Store Connect:** add Data Shared with Third Parties → User Content → App Functionality, not linked, not tracking; name Anthropic. Update `AppStore/privacy.md` to name Anthropic + list both flows (transform text, teach-back text).

## HIGH

3. **3.1.1 — "bring your own API key" framing.** There's active Apple precedent reading "key unlocks functionality" as circumventing IAP. Defensible here (free app, no IAP, all core features work keyless, key = the user's own pre-paid Anthropic account).
   → **Code:** reframe Settings "AI" section as linking *your own Anthropic account* (billed by Anthropic). **Review notes:** make the argument explicitly.
4. **2.3 — "No key needed for short transforms" is false on the reviewer's device.** On-device Apple Intelligence is gated to iOS 26+; reviewers run production iOS, so every AI task falls through to the keyed cloud path. Onboarding promises otherwise.
   → **Code:** qualify the onboarding copy. **Review notes:** supply a temporary Anthropic key + state core app works keyless.
5. **ITMS-91053 — Readium bundles ship UserDefaults usage with no `PrivacyInfo.xcprivacy`.** SDK-level missing manifest is a real 2024+ rejection cause.
   → **Build:** add a post-build phase injecting a minimal manifest into the Readium bundles (or file upstream + pin a fixed version).
6. **2.1 — dead `.mlxLocal` scaffold in the routing table.** `LocalProvider` throws "MLX wiring not yet implemented"; `.mlxLocal` is listed in every `LLMRouter.plan()` but always skipped.
   → **Code:** remove `.mlxLocal` from the plans + `LLMTypes` (dead) or complete it. Don't ship a named-but-broken model.

## MEDIUM

7. **2.3.7 — trademarked keywords** "claude", "kindle" in `AppStore/listing.md`. Remove both.
8. **5.2.1 — trademarks in the public description**: "Claude" and "Joan Didion" appear in `listing.md`. Use generic phrasing ("a cloud AI model (Anthropic)"; "a spare, literary essay"). (The in-app style presets were already de-named.)
9. **Privacy policy URL is a GitHub blob** (`SettingsView` + ASC). Host a rendered page (GitHub Pages) and 404-proof it.
10. **`LSRequiresIPhoneOS=false`** exposes an untested Mac (Designed-for-iPad) path that could crash review. Set `true` unless Mac is verified.
11. **Content-safety guard in transform system prompts** (`PromptTemplates`): add a one-line "never produce adult/violent/hateful/illegal content" clause — cheap reviewer-confidence + age-rating cover. (Full UGC moderation **not** required: no social surface, AI output is private to the user.)
12. **4.3(b) "adds value" (Jun 2026 update)** — document the differentiators (import, TTS word-highlight, spaced repetition, on-device AI) in review notes so it isn't mistaken for a Blinkist clone.

## LOW / hygiene
- Force-unwrapped URL literal in `SettingsView` (AI-code tell) → make a non-optional constant.
- Pricing inconsistency in `listing.md` ("one-time $9.99" vs free) — reconcile.
- Cover SVGs show the real title as dominant text — keep "THE BIG IDEAS IN" eyebrow visually dominant (already present) as a reference framing.
- Account deletion 5.1.1(v): exempt (no accounts); note it in review notes. Reset-all-content already exists.

## Not required (confirmed)
- 1.2 UGC report/block mechanism — N/A (no sharing; AI output is private to the user).
- Background-audio mode (TTS) — justified and implemented.

## Implementation note — Readium privacy manifest (#5)
The post-build manifest-injection script was removed: it tripped Xcode's
user-script sandbox (`ENABLE_USER_SCRIPT_SANDBOXING=YES`). Apple aggregates
privacy manifests across the whole bundle, and the app target already declares
UserDefaults (CA92.1), which most likely covers Readium's usage. **Watch-item:**
if a submission returns ITMS-91053/91061 naming a Readium bundle, either pin a
Readium release that ships its own `PrivacyInfo.xcprivacy` or re-add the
injection as a sandbox-exempt phase (or run it from CI before upload).
