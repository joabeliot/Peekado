# Notion token lives in the Keychain

**Date:** 2026-09-04
**Status:** Decided

## Decided
The Notion integration token is stored as a Keychain generic-password item
(`KeychainStore`), entered through a `SecureField` in the Settings panel. The
non-secret runtime config (database id, property names) sits in `UserDefaults`,
also entered in Settings — see `decisions/nsstatusitem-over-menubarextra.md` and
`features/settings-config.md`. Nothing real is committed.

## Why
- A token in source or `UserDefaults` leaks the moment the repo is shared or a
  backup is read. The repo is meant to be shareable.
- Keychain gives at-rest encryption and per-app ACL for free.
- Entering it in-app means the running app writes the item itself, so it's
  trusted to read it back without a scary prompt on every launch.

## Rejected
- **`UserDefaults` / a plist for the token** — plaintext. (Fine for the
  *non-secret* config, which is where it ended up.)
- **A gitignored `Secrets.swift`** — still on disk in the clear; easy to
  commit by accident.
- **Env var / launchctl** — clunky for a double-click menu bar app.

## Consequences
- First run needs a one-time setup in Settings: database id + token.
- Rebuilds under "Sign to Run Locally" change the app's identity and can
  re-prompt for Keychain access — "Always Allow" clears it.
- History was rewritten once to remove a real `databaseID` + workspace name that
  had been committed during bring-up. Keep real ids out of git — including
  commit messages. (Now moot: the id lives in UserDefaults, never source.)
