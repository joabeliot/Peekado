# Architecture — Models

## `TodoTask` (`TaskModel.swift`)

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Notion **page** id. PATCH targets this. A `temp-<uuid>` value marks an optimistic row not yet confirmed by Notion. |
| `title` | `String` | Concatenated `plain_text` runs of the title property. `"(untitled)"` if empty. |
| `done` | `Bool` | Optimistic local flag. `true` when status == `Config.doneStatusValue` at fetch time, or after a local toggle. |
| `originalStatus` | `String` | Status value at fetch time. Used to restore the task when it's un-checked in the same session. |
| `dueTime` | `Date?` | Set only when the date property's `start` carried a time component (`…T…`). |

`Identifiable`, `Equatable`. Named `TodoTask` — **not** `Task` (Swift concurrency clash).

## Notion JSON — the shapes we parse (`NotionClient`)

- **Title:** `properties[titleProperty].title[] → .plain_text` (also falls back to `.rich_text`).
- **Status/Select:** `properties[statusProperty].status.name` OR `.select.name`.
  Which one is driven by `Config.statusPropertyKind` (`.status` | `.select`).
- **Date:** `properties[dateProperty].date.start`. Date-only (`yyyy-MM-dd`) → no
  `dueTime`. Datetime → parsed by `ISO8601DateFormatter`, tried with and without
  fractional seconds.
- **Today** for the query filter is `yyyy-MM-dd` in the Gregorian calendar,
  `en_US_POSIX` locale, device local time.

Parsing is `JSONSerialization` + dictionary casting (not `Codable`) because
Notion's property payloads are polymorphic. A row that fails to parse is dropped
(`compactMap`), not fatal.

## Config surface (`Config.swift`)

`databaseID` (placeholder in git) · `titleProperty` · `dateProperty` ·
`statusProperty` · `statusPropertyKind` · `doneStatusValue` ·
`newTaskStatusValue` (`""` ⇒ create tasks with no status) · `notionAPIVersion`.
