# Release checklist

A walk-through for shipping BookApp to the App Store. Roughly in order.

## Identity

- [ ] Bundle ID: change `com.bookapp.app` in `project.yml` to a unique ID
      under your team (e.g. `com.lukataylo.bookapp`). Re-run `xcodegen`.
- [ ] iCloud container: rename `iCloud.com.bookapp.app` to match (in
      `project.yml`, `Info.plist`, and `BookApp.entitlements`). Provision
      the new container in Apple Developer → Identifiers → iCloud
      Containers.
- [ ] App ID: enable iCloud, CloudKit, and Background Modes (Audio) in
      the Apple Developer portal.
- [ ] Provisioning profiles: create dev + distribution provisioning
      profiles tied to the new bundle ID.
- [ ] Set DEVELOPMENT_TEAM in Xcode (or in `project.yml` under
      `settings.base.DEVELOPMENT_TEAM`).

## Marketing assets

- [ ] App icon: already at
      `BookApp/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`.
      Re-run `python3 scripts/generate-icon.py` if you want to tweak.
- [ ] Five iPhone 6.7" screenshots (1290×2796) — see
      `AppStore/listing.md → Screenshots brief`.
- [ ] Five iPhone 6.1" screenshots (1170×2532) — same compositions.
- [ ] (optional) Five iPad 13" screenshots (2048×2732).
- [ ] App Preview video — 30s walk-through, optional.

## App Store Connect

- [ ] Create the app record with the bundle ID.
- [ ] Paste in `AppStore/listing.md`'s name, subtitle, description, keywords.
- [ ] Privacy URL: link to `AppStore/privacy.md` hosted on GitHub Pages or
      similar (the App Store wants a public URL).
- [ ] Privacy nutrition: see `AppStore/data-safety.md`.
- [ ] Age rating: 4+.
- [ ] Category: Books / Productivity.
- [ ] Pricing: **Free** (no in-app purchases, no subscriptions).
- [ ] Build: archive in Xcode (Product → Archive), upload, attach to the
      App Store record.
- [ ] Export Compliance: BookApp uses the system's HTTPS only (URLSession
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
