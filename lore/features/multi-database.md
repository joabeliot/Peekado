# Feature: Multiple database profiles

**Status:** Done

## What It Does
Peek-A-Do can hold several Notion databases. Each is a `DatabaseProfile`
(name + database id + title/date/status property names). The **primary** profile
— chosen by a radio button in the Settings window — is the one the dropdown
shows. Switch primary anytime; an open dropdown re-fetches immediately
(`.onChange(of: settings.primaryID)`).

All profiles share the **one** integration token (they're expected to be in the
same workspace / shared with the same integration).

## How it's wired
- `AppSettings` holds `[DatabaseProfile]` + `primaryID`, persisted as JSON under
  `notion.profiles` / `notion.primaryProfileID`.
- On every change, the primary profile's values are **mirrored** into the flat
  `Config.Key.*` UserDefaults keys. `Config` and `NotionClient` still just read
  those keys — they don't know profiles exist. This keeps the off-main-actor
  read path unchanged.
- First launch on this version with no `notion.profiles`: the old single flat
  config is migrated into one profile named "My tasks", set primary.

## Edge Cases
- Deleting the primary promotes `profiles.first` to primary. Can't delete the
  last profile (trash button disabled).
- A profile with an empty database id → dropdown shows `.missingDatabaseID` with
  an "Open Settings" button.
- `statusPropertyKind` / `doneStatusValue` / `newTaskStatusValue` are still
  global `Config` constants — every profile shares them. Per-profile status
  config isn't built; edit `Config.swift` if one DB differs.

## Open Questions
- Quick-switch primary from a menu on the menu bar icon (currently Settings only)?
- Per-profile status type / done value?

## Notes
Files: `DatabaseProfile.swift`, `AppSettings.swift`, `SettingsView.swift`,
`TaskListView` (header name + onChange refresh). See
`decisions/multi-db-profiles.md`, `decisions/settings-window.md`.
