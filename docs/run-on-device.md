# Run BookApp on your iPhone

A free Apple ID plus Xcode is enough — no paid Apple Developer membership
required. The build expires after **7 days** and re-installs each time you
re-build. For permanent installs you need a paid Developer Program
membership ($99/yr) and a real provisioning profile.

This guide assumes you already cloned the repo and ran `xcodegen generate`
once.

## Quick checklist

1. iPhone with iOS 18 or later, a Lightning / USB-C cable, and an Apple ID.
2. Xcode 26 (you've already got this if everything else has been working).
3. Pick a unique bundle ID — `com.<yourname>.bookapp` is fine.
4. Decide on iCloud:
   - **Free Apple ID:** iCloud sync needs a paid account, so we'll strip
     the iCloud / CloudKit entitlements for the on-device build. The app
     still works fine; the model container falls back to a local SQLite
     store.
   - **Paid Apple Developer ($99/yr):** keep iCloud, but create a new
     container in the Developer portal to match your bundle ID.

## Step 0 — set your team id once (recommended)

`xcodegen generate` overwrites the Xcode project, which means the **Team**
field you pick in *Signing & Capabilities* gets blanked every time you
regenerate. To make your team id stick:

```bash
cp BookApp/Supporting/Local.xcconfig.example BookApp/Supporting/Local.xcconfig
# Edit BookApp/Supporting/Local.xcconfig and replace ABCDE12345 with your
# actual 10-character team id from
#   https://developer.apple.com/account/resources/identifiers
xcodegen generate
```

`Local.xcconfig` is gitignored — your team id stays out of the repo.
Future `xcodegen generate` runs honour whatever's in it.

## Step 1 — pick a unique bundle ID

`com.bookapp.app` is generic and will clash with anything else under your
Apple ID. Open `project.yml`, change two things:

```yaml
settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: com.<yourname>.bookapp     # e.g. com.lukadadiani.bookapp
```

If you're going the iCloud route, also rename the container in
`project.yml`, `BookApp/Supporting/Info.plist`, and
`BookApp/Supporting/BookApp.entitlements`:

```
iCloud.com.bookapp.app   →   iCloud.com.<yourname>.bookapp
```

Re-generate the Xcode project:

```bash
cd /Users/lukadadiani/Documents/book-app
xcodegen generate
```

## Step 2 — strip iCloud (free-account path only)

Open `BookApp/Supporting/BookApp.entitlements` in any text editor and
delete the four iCloud-related keys: `com.apple.developer.icloud-*` and
`com.apple.developer.ubiquity-*`. Keep `com.apple.security.app-sandbox`,
`com.apple.security.files.user-selected.read-write`,
`com.apple.security.network.client`, and the audio one.

Then in `BookApp/App/ModelContainer+BookApp.swift` change the production
container call to use the local store. The app already falls back to a
local container when CloudKit setup fails, so even leaving it as-is just
means you'll see a warning in the console once at launch — pick whichever
you prefer.

Re-run `xcodegen generate` if you edited `project.yml`.

## Step 3 — connect your phone and trust the Mac

1. Plug the iPhone into the Mac with the cable.
2. Unlock the phone. A "Trust This Computer?" prompt appears — tap **Trust**
   and enter your passcode.
3. In Xcode → **Window → Devices and Simulators**, your phone should appear
   in the left column with a green dot.

## Step 4 — Xcode signing

1. Open the generated project: `open BookApp.xcodeproj`.
2. Click the **BookApp** target in the project navigator.
3. Go to **Signing & Capabilities**.
4. Tick **Automatically manage signing**.
5. Pick your **Team** from the dropdown — your Apple ID appears as
   "Your Name (Personal Team)" once you've added it via *Xcode → Settings
   → Accounts*.
6. Verify the bundle ID matches what you set in step 1.

If you stripped iCloud in step 2, the iCloud capability section here
should be empty. Confirm there's no red error banner.

## Step 5 — build and run

1. At the top of Xcode's window, change the destination from a simulator
   to your iPhone's name.
2. Hit **Cmd+R** (or click the play arrow).

First run will take 60–90 seconds — Xcode is signing every linked
framework with your personal team.

## Step 6 — trust the developer cert on the phone

iOS won't run an app signed with a personal team until you tell it to.

1. On the iPhone, **Settings → General → VPN & Device Management**.
2. Under **Developer App**, tap your Apple ID.
3. Tap **Trust "Your Name (Personal Team)"**, confirm.

Now go back to the home screen — the BookApp icon (the serif "B" on cream)
is there. Open it.

## What to expect on first run

- The library's auto-categorised shelves show up immediately because the
  bundled `SeedBooks/` folder is part of the app and seeds on first
  launch (curated metadata in code; no API calls needed).
- The Prince has 4 variants (Original + 2 compressions + Harari restyle)
  pre-baked. Beyond Good & Evil has 2 (Original + 1 compression). The
  Republic has Original only. Generating the rest needs an Anthropic API
  key in Settings → AI on the phone, then tapping "Generate" in the
  Transformation Studio.
- TTS uses your iPhone's premium Siri voices — the first time you pick
  one, iOS downloads it (a few hundred MB).

## Wireless debugging (nice-to-have)

Once you've done step 3 over cable, in Xcode → Window → Devices and
Simulators → tick **Connect via network**. You can unplug the cable and
keep deploying.

## "It expired" — re-installing every 7 days

Free-account signing expires after 7 days. Just re-build from Xcode and
the app will re-deploy with a fresh signature. No data lost (the SwiftData
store on the device persists across reinstalls of the same bundle ID).

## Anthropic API key on the phone

Your macOS Keychain key isn't visible to iOS. On the phone:

1. Open BookApp → **Settings tab → AI**.
2. Paste your Anthropic API key. It goes into the iPhone's Keychain.
3. The cloud-transform features unlock immediately.

## If signing fails

- "iCloud container ... is not allowed for this app ID" — strip the
  iCloud entitlements (step 2) or upgrade to paid.
- "Could not launch ... operation couldn't be completed" — open the
  iPhone, trust the developer (step 6), then re-tap Run.
- "Multiple commands produce ..." — re-run `xcodegen generate` after any
  change to `project.yml`.
