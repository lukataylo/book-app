# App Store data-safety questionnaire — answers

Use these when filling out the Privacy section in App Store Connect.

## Data Collection

> **Do you or your third-party partners collect data from this app?**

**No** — for everything BookApp itself handles.

The Anthropic API requests (which you initiate explicitly) are governed by
Anthropic's own data policy. App Store Connect treats those as third-party
collection only if BookApp passes user-identifying data; we don't pass any
identifier (no name, email, account, advertising ID). The text content of
the book you choose to transform is sent under your own API key. Declare
this honestly:

| Data type | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|
| User content (book text you transform) | No | No | App functionality (the transformation you requested) |

Set everything else to "Data not collected".

## Privacy practices summary (the nutrition-label result)

- **Data Not Collected** by BookApp.
- **Data Not Linked to You**: User content (book text passed to Anthropic when you choose).
- No tracking.

## App Privacy Details — long form

### What user data does the app handle?

- Books you import (stay local + iCloud private DB).
- Reading position, highlights, key learnings (stay local + iCloud private DB).
- Anthropic API key (Keychain, never transmitted to BookApp).
- Voice / typography / margin preferences (Keychain + iCloud private DB).

### What data leaves the device?

- Only the prompt + source text for a cloud transformation, sent directly
  to `api.anthropic.com` under the user's API key. The user must confirm
  each cloud run.
- iCloud sync for metadata + transformation outputs to the user's private
  CloudKit database.

### Is anything used for tracking?

No.

### Is anything sold to third parties?

No.
