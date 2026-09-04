# Feature: Settings-based Notion config

**Status:** Done — superseded in detail by `multi-database.md` (the config is now
a list of profiles, and Settings is a window). Kept for the "why config left
source" rationale.

## What It Does
The Settings window (gear, or right-click the menu bar icon) holds the whole
Notion setup — no more editing source:

- **Database profiles** — see `features/multi-database.md`. Each has a database
  id + title/date/status property names.
- **Integration token** — Keychain via `KeychainStore` / `AppSettings`.
- **Start at login** — `SMAppService`.

Everything persists as it's edited (`AppSettings` `didSet`). Empty primary
`databaseID` → the dropdown shows `.missingDatabaseID` + an "Open Settings" button.

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
