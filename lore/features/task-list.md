# Feature: Today's task list

**Status:** Done

## What It Does
The dropdown's core. On every open it queries Notion for pages due today (Done
included) and shows them in a `List` — a status glyph, the title, an optional
status badge, an optional time on the right. Open tasks sort first (by time),
completed last. Clicking a row marks it done: the glyph fills and the title
strikes through in place, then a PATCH goes to Notion. On failure it reverts and
beeps. The footer shows "X of Y done".

### Status glyph + badge
- done → filled accent check, strikethrough
- in progress (status == `Config.inProgressStatusValue`) → half-filled **orange**
  circle + orange "IN PROGRESS" badge
- any other non-done status that isn't the plain "to do" value → a grey uppercase
  badge with the raw status text ("BLOCKED", "REVIEW", …)
- plain to-do / no status → empty circle, no badge

`isInProgress` / `statusBadge` in `TaskListView` derive this from
`TodoTask.originalStatus` (the status name captured at fetch).

## Edge Cases
- Zero tasks → "Nothing on deck 🎉". Footer summary hides when the list is empty.
- No token → error state pointing at Settings.
- Re-opening with a list already loaded doesn't flash the spinner.
- Checking a task keeps it visible (struck through); it stays on the next fetch
  as a Done row. List only re-sorts on refresh, not on the toggle itself.
- Un-checking: restores `originalStatus`; if that was already `Done` or empty,
  falls back to `Config.newTaskStatusValue`.

## Assumptions
- Database has a title, a date, and a status/select property — names in `Config`.
  Validate by: the user editing `Config.swift` to match their DB.
- < 100 tasks per day. Validate by: fine for personal use; revisit if it bites.

## Open Questions
- Sort: open-by-time then done-by-time. Worth a manual order?
- Cap is 100 tasks/day, unpaginated — fine for now.

## Notes
Files: `TaskListView.swift` (view + `TaskListModel`), `NotionClient.fetchTodaysTasks`
/ `setDone`, `TodoTask`.
