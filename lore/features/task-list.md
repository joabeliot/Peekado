# Feature: Today's task list

**Status:** Done

## What It Does
The dropdown's core. On every open it queries Notion for pages due today (Done
included) plus incomplete tasks (To do, In progress, etc.) from the past 7 days,
and shows them in a `List` — a status glyph, the title, an optional
status badge, an optional time on the right. Overdue incomplete tasks are
asynchronously updated in Notion to today's date, while past Done tasks remain
in the past and are excluded. The list is grouped by tier — **to-do → in progress → done**, then by time
(`TaskListModel.ordered` / `rank`). Clicking a row **advances its status** one
step around `TaskListModel.statusCycle()` — `to do → in progress → done → to do`
(`[newTaskValue, inProgressValue, doneValue]`, deduped, empties dropped; an
unrecognised current status jumps straight to done). Optimistic
(`NotionClient.setStatus`), reverts + beeps on failure. Footer shows "X of Y done".

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
- Advancing a task re-sorts the list right away (animated) so it moves into its
  new tier; the row doesn't stay in place.
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
Files: `TaskListView.swift` (view + `TaskListModel` — `advance`, `statusCycle`,
`isInProgress`, `statusBadge`), `NotionClient.fetchTodaysTasks` / `setStatus`,
`TodoTask`.
