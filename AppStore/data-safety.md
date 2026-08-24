# App Store data-safety questionnaire — answers

Use these when filling out the Privacy section in App Store Connect.

## Data Collection

> **Do you or your third-party partners collect data from this app?**

**No** — for everything Epigrapha itself handles.

The requests to **Anthropic** (which you initiate explicitly) are governed
by Anthropic's own data policy. App Store Connect treats those as
third-party collection only if Epigrapha passes user-identifying data; we
don't pass any identifier (no name, email, account, advertising ID). What
is sent under your own API key is the book / source text you choose to
transform. The app does not store it, and there is no account. Declare this honestly:

| Data type | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|
| User content (the book / source text you choose to transform) | No | No | App functionality (the transformation you requested) |

Set everything else to "Data not collected".

### Data shared with third parties

**Anthropic — User Content — App Functionality — not linked to identity,
not used for tracking.** Sent only with the user's own Anthropic API key,
only after explicit, named, withdrawable consent, and never stored by the
app.

> This row must actually be entered in App Store Connect. Review
> cross-checks the nutrition label against observed network behaviour, and
> the app does contact `api.anthropic.com`. A label claiming no
> third-party sharing is a mismatch even though the sharing is optional.

## Privacy practices summary (the nutrition-label result)

- **Data Not Collected** by Epigrapha.
- **Data Not Linked to You**: User content (book/source text passed to Anthropic when you choose).
- **Third party**: Anthropic only, under the user's own API key, not stored by the app.
- No tracking. No account.

## App Privacy Details — long form

### What user data does the app handle?

- The bundled catalog: 28 public-domain works, each with an original
  summary and quick take (ship inside the app; nothing is fetched).
- Books you import (stay local + iCloud private DB).
- Reading position, highlights and bookmarks (stay local + iCloud
  private DB).
- Anthropic API key (Keychain, never transmitted to Epigrapha).
- Voice / typography / margin preferences (iCloud private DB).

### What data leaves the device?

- Only the prompt + source text for a cloud transformation, sent directly
  to `api.anthropic.com` under the user's API key, and only after the user
  has granted permission in a dialog naming Anthropic. Until then the
  provider reports itself unavailable and no connection is opened. The
  permission is withdrawable in Settings → Privacy. The app does not
  store this data.
- Nothing else. Automatic category tagging of imported books runs
  on-device only and never falls back to the network.
- iCloud sync for metadata + transformation outputs to the user's private
  CloudKit database.

### Is anything used for tracking?

No.

### Is anything sold to third parties?

No.
