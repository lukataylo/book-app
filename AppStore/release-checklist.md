# Release checklist

A walk-through for shipping Epigrapha to the App Store. Roughly in order.

## Identity

- [x] Bundle ID: `com.lukataylor.bookapp`. Note this is unchanged from
      before the rename to Epigrapha — the id is not user-visible, and
      moving it would invalidate provisioning and the CloudKit container.
- [x] iCloud container: `iCloud.com.lukataylor.bookapp`. Provision it in
      Apple Developer → Identifiers → iCloud Containers if not already.
- [ ] App ID: enable iCloud, CloudKit, and Background Modes (Audio) in
      the Apple Developer portal.
- [ ] Provisioning profiles: create dev + distribution provisioning
      profiles tied to the new bundle ID.
- [ ] Set DEVELOPMENT_TEAM in Xcode (or in `project.yml` under
      `settings.base.DEVELOPMENT_TEAM`).

## Marketing assets

- [x] App icon: open book, gold on near-black, at
      `BookApp/Resources/Assets.xcassets/AppIcon.appiconset/`. Default,
      dark and tinted variants all present.
- [ ] Screenshots (1290×2796). **Must be regenerated** — the shelf, the
      book page and the reader all changed when full texts landed, and the
      brief in `listing.md` was rewritten to lead with the three length
      tiers (the 4.3(b) differentiator). Regenerate with
      `xcodebuild test -only-testing:BookAppUITests/StoreShotTests`, and
      **erase the simulator first** — a stale store seeded by an older
      loader key will put withdrawn titles on the shelf.
- [ ] iPhone 6.1" screenshots (1170×2532) — optional; App Store Connect
      will scale the 6.9" set if omitted.
- [ ] (optional) Five iPad 13" screenshots (2048×2732).
- [ ] App Preview video — 30s walk-through, optional.

## App Store Connect

- [ ] Create the app record with the bundle ID.
- [ ] Paste in `AppStore/listing.md`'s name, subtitle, description, keywords.
- [ ] **Enable GitHub Pages** (repo Settings → Pages → Source: *GitHub
      Actions*), then push to `main` so `.github/workflows/pages.yml`
      runs. It publishes `/privacy/` and `/support/` from
      `AppStore/privacy.md` + `site/`, and fails the job if either URL
      doesn't return 200 — so a green run *is* the verification. The app
      and the listing both already point at those URLs.
- [ ] Privacy nutrition: see `AppStore/data-safety.md`. **Do not leave it
      as "no data collected"** — the label must carry *Data Shared with
      Third Parties → User Content → App Functionality*, naming Anthropic,
      not linked to identity, not used for tracking. Review cross-checks
      the label against observed network behaviour.
- [ ] Age rating: 4+.
- [ ] Category: Books / Productivity.
- [ ] Pricing: **Free** (no in-app purchases, no subscriptions).
- [ ] Build: archive in Xcode (Product → Archive), upload, attach to the
      App Store record.
- [ ] Export Compliance: Epigrapha uses the system's HTTPS only (URLSession
      to Anthropic + CloudKit). Standard ATS — declare "uses standard
      encryption", no extra paperwork.

## Pre-flight (code)

These are done and verified in the tree; re-check after any change.

- [x] 5.1.2(i) consent is enforced at the network boundary
      (`ClaudeProvider.isAvailable`), not at call sites, and is
      withdrawable in Settings → Privacy. Pinned by `CloudConsentTests`.
- [x] Auto-tagging on import is on-device only — it never falls back to
      the cloud.
- [x] "Reset all content" clears the key the loader actually reads
      (`SummaryPackLoader.resetSeedFlag`). Previously it cleared a stale
      `-v2` key, so a reset emptied the app permanently.
- [x] MOBI removed from `Info.plist`, the picker, the parser and all copy —
      it never worked, and declaring the UTI made iOS offer the app as a
      handler that always failed.
- [x] Listing, README and onboarding describe features that exist.
- [x] Privacy manifest declares exactly what the app uses (UserDefaults,
      `CA92.1`). Readium's ZIPFoundation ships its own manifest, so
      ITMS-91053 is covered.
- [x] Reader chrome scales with Dynamic Type; the transport bar is capped
      at `accessibility2` so it still fits.
- [x] 64 unit tests + the Listen-flow UI test pass on iPhone 17 Pro.

## Final review

- [ ] Smoke test on a real device: open a bundled title at all three
      lengths, import a Project Gutenberg EPUB, compress it, listen to a
      chapter, run speed-reading mode.
- [ ] Tap **Reset all content**, relaunch, and confirm the catalog comes
      back. (This was broken; the fix is tested but worth seeing.)
- [ ] With no API key and no consent granted, confirm the Transformation
      Studio explains itself rather than failing silently.
- [ ] Test offline behavior: airplane-mode the device, verify reader /
      TTS / speed reader still work, and that cloud transformations
      surface a clear "needs internet" state.
- [ ] iCloud round-trip: install on a second device, confirm shelf and
      reading position appear within a minute.
- [ ] Check that no API key is in any committed file: `git grep "sk-ant"`
      should return nothing.
- [ ] Submit for review. Allow ~24-48h.
