# Feature: Settings-based Notion config

**Status:** Done

## What It Does
The Settings panel (gear) now holds the whole Notion setup, not just the token:

- **Database ID** + **Title / Date / Status property names** — text fields bound
  to `AppSettings` (`@Published`), persisted to `UserDefaults` on **Save** under
  `Config.Key.*`. `Config` reads those keys back (thread-safe, so `NotionClient`
  off the main actor is fine). Empty `databaseID` → `refresh()` shows
  "add it in Settings" instead of hitting Notion.
- **Integration token** — unchanged, still Keychain via `KeychainStore`.
- **Start at login** — unchanged (`SMAppService`).

One **Save** button persists everything and calls `refresh()`.

## Why
Editing `Config.swift` (or the old `LocalConfig.swift` + skip-worktree) to point
the app at a database is a non-starter for anyone who isn't building from source.
This is step 1 of `ideas/distributable-app.md`.

## Edge Cases
- Fields trim whitespace on Save.
- `statusPropertyKind`, `doneStatusValue`, `newTaskStatusValue` are **not** in
  the panel — still `Config` constants. The panel shows their current values as a
  hint. Revisit if users actually need to change them.
- Token field shows a "saved — paste to replace" placeholder when one exists;
  leaving it blank on Save keeps the existing token.

## Notes
Files: `AppSettings.swift`, `Config.swift` (UserDefaults-backed computed vars),
`TaskListView.settingsPanel` / `settingField`, `NotionClient` (`.missingDatabaseID`).
`LocalConfig.swift` was deleted.
