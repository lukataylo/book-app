# App Store data-safety questionnaire — answers

Use these when filling out the Privacy section in App Store Connect.

## Data Collection

> **Do you or your third-party partners collect data from this app?**

**No** — for everything BookApp itself handles.

The requests to **Anthropic** (which you initiate explicitly) are governed
by Anthropic's own data policy. App Store Connect treats those as
third-party collection only if BookApp passes user-identifying data; we
don't pass any identifier (no name, email, account, advertising ID). What
is sent under your own API key is (a) the book / source text you choose to
transform, and (b) the explanation you type during teach-back grading when
on-device AI is unavailable. The app does not store either, and there is no
account. Declare this honestly:

| Data type | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|
| User content (book/source text you transform, and teach-back text when graded in the cloud) | No | No | App functionality (the transformation or grading you requested) |

Set everything else to "Data not collected".

### Data shared with third parties

**Anthropic — User Content — App Functionality — not linked to identity,
not used for tracking.** Sent only with the user's own Anthropic API key,
only on explicit confirmation, and never stored by the app.

## Privacy practices summary (the nutrition-label result)

- **Data Not Collected** by BookApp.
- **Data Not Linked to You**: User content (book/source text, and teach-back grading text, passed to Anthropic when you choose).
- **Third party**: Anthropic only, under the user's own API key, not stored by the app.
- No tracking. No account.

## App Privacy Details — long form

### What user data does the app handle?

- Books you import (stay local + iCloud private DB).
- Reading position, highlights, key learnings, saved knowledge cards and
  action-plan progress (stay local + iCloud private DB).
- Calendar events / reminders the user explicitly exports from an action
  plan (written to the system Calendar/Reminders via EventKit; calendar
  access is write-only and nothing is read back or transmitted).
- Anthropic API key (Keychain, never transmitted to BookApp).
- Voice / typography / margin preferences (Keychain + iCloud private DB).

### What data leaves the device?

- Only the prompt + source text for a cloud transformation, and the user's
  typed explanation during teach-back grading when on-device AI is
  unavailable, sent directly to `api.anthropic.com` under the user's API
  key. The user must confirm each cloud run. The app does not store this
  data.
- iCloud sync for metadata + transformation outputs to the user's private
  CloudKit database.

### Is anything used for tracking?

No.

### Is anything sold to third parties?

No.
