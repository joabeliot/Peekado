# Notion token lives in the Keychain

**Date:** 2026-09-04
**Status:** Decided

## Decided
The Notion integration token is stored as a Keychain generic-password item
(`KeychainStore`), entered through a `SecureField` in the Settings popover.
`Config.swift` holds only non-secret values, and its `databaseID` ships as a
placeholder string.

## Why
- A token in source or `UserDefaults` leaks the moment the repo is shared or a
  backup is read. The repo is meant to be shareable.
- Keychain gives at-rest encryption and per-app ACL for free.
- Entering it in-app means the running app writes the item itself, so it's
  trusted to read it back without a scary prompt on every launch.

## Rejected
- **`UserDefaults` / a plist** — plaintext.
- **A gitignored `Secrets.swift`** — still on disk in the clear; easy to
  commit by accident.
- **Env var / launchctl** — clunky for a double-click menu bar app.

## Consequences
- First run needs a one-time paste (gear → paste → Save).
- Rebuilds under "Sign to Run Locally" change the app's identity and can
  re-prompt for Keychain access — "Always Allow" clears it.
- History was rewritten once to remove a real `databaseID` + workspace name that
  had been committed during bring-up. Keep real ids out of git — including
  commit messages.
