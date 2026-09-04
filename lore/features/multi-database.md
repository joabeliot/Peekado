# Feature: Multiple database profiles

**Status:** Done

## What It Does
Peek-A-Do can hold several Notion databases. Each is a `DatabaseProfile`
(name + database id + title/date/status property names + status kind / done /
to-do values). The **primary** profile — chosen by a radio button in the
Settings window — is the one the dropdown shows. Switch primary anytime; an open
dropdown re-fetches immediately (`.onChange(of: settings.primaryID)`).

### Adding one — paste the id (or the whole URL), that's it
`NotionClient.canonicalDatabaseID` strips a pasted full Notion URL / the `?v=`
view id / dashes down to the bare 32-hex id first. Then "Add & set up" (or a
row's "Re-detect") calls `NotionClient.fetchDatabaseSchema` → `GET /v1/databases/{id}`
and fills in:
- **name** from the database title
- **title / date / status property** by property `type`; a name regex
  (`due|date…`, `status|state…`) breaks ties when there's more than one candidate
- **status kind** from whether the property is `status` or `select`
- **done / in-progress / to-do values** by matching option names
  (`^(done|complete…)$`, `^(in.?progress|doing|wip…)$`, `^(to.?do|not started…)$`),
  else `"Done"` / `"In progress"` / first option

Every field stays editable under each row's **Edit** disclosure.

All profiles share the **one** integration token (same workspace / same
integration).

## How it's wired
- `AppSettings` holds `[DatabaseProfile]` + `primaryID`, persisted as JSON under
  `notion.profiles` / `notion.primaryProfileID`.
- On every change, the primary profile's values are **mirrored** into the flat
  `Config.Key.*` UserDefaults keys (now including `statusKind` / `doneValue` /
  `newTaskValue`). `Config` and `NotionClient` still just read those keys — they
  don't know profiles exist. Keeps the off-main-actor read path unchanged.
- First launch on the multi-DB version with no `notion.profiles`: the old single
  flat config is migrated into one profile named "My tasks", set primary.
- `DatabaseProfile` has a lenient `init(from:)` so profiles written before the
  status fields existed still decode (fallback defaults).

## Edge Cases
- Deleting the primary promotes `profiles.first` to primary. Can't delete the
  last profile (trash button disabled).
- A profile with an empty database id → dropdown shows `.missingDatabaseID` with
  an "Open Settings" button.
- Detect failure (bad id, DB not shared with the integration, no title/date/
  status property) shows an inline error on the row; the row keeps whatever was
  pasted so it can be fixed + re-detected.
- `notionAPIVersion` is still the one global `Config` constant.

## Open Questions
- Quick-switch primary from a menu on the menu bar icon (currently Settings only)?

## Notes
Files: `DatabaseProfile.swift`, `AppSettings.swift` (`detectSchema`,
`addProfile(databaseID:)`), `SettingsView.swift`, `NotionClient.fetchDatabaseSchema`,
`TaskListView` (header name + onChange refresh). See
`decisions/multi-db-profiles.md`, `decisions/settings-window.md`.
