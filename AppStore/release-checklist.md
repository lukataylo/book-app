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
- [x] Three iPhone 6.9" screenshots (1290×2796) in
      `AppStore/screenshots/`. One illustration spans all three panels, so
      keep their order. Regenerate with
      `xcodebuild test -only-testing:BookAppUITests/StoreShotTests`, and
      **erase the simulator first** — a stale store will put in-copyright
      titles in the shelf.
- [ ] iPhone 6.1" screenshots (1170×2532) — optional; App Store Connect
      will scale the 6.9" set if omitted.
- [ ] (optional) Five iPad 13" screenshots (2048×2732).
- [ ] App Preview video — 30s walk-through, optional.

## App Store Connect

- [ ] Create the app record with the bundle ID.
- [ ] Paste in `AppStore/listing.md`'s name, subtitle, description, keywords.
- [ ] Privacy URL: **BLOCKER — https://lukataylo.github.io/book-app/privacy
      currently returns 404.** App Review rejects a dead privacy URL.
      Publish `AppStore/privacy.md` to GitHub Pages (or anywhere public)
      before submitting, and update the link in Settings → About, which
      points at the same dead URL.
- [ ] Privacy nutrition: see `AppStore/data-safety.md`.
- [ ] Age rating: 4+.
- [ ] Category: Books / Productivity.
- [ ] Pricing: **Free** (no in-app purchases, no subscriptions).
- [ ] Build: archive in Xcode (Product → Archive), upload, attach to the
      App Store record.
- [ ] Export Compliance: Epigrapha uses the system's HTTPS only (URLSession
      to Anthropic + CloudKit). Standard ATS — declare "uses standard
      encryption", no extra paperwork.

## Final review

- [ ] Smoke test on a real device: import a Project Gutenberg EPUB,
      compress it, listen to a chapter with TTS, run speed-reading mode.
- [ ] Test offline behavior: airplane-mode the device, verify reader /
      TTS / speed reader still work, and that cloud transformations
      surface a clear "needs internet" state.
- [ ] iCloud round-trip: install on a second device, confirm shelf and
      reading position appear within a minute.
- [ ] Check that no API key is in any committed file: `git grep "sk-ant"`
      should return nothing.
- [ ] Submit for review. Allow ~24-48h.
