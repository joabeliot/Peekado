# Feature: Today's task list

**Status:** Done

## What It Does
The dropdown's core. On every open it queries Notion for pages where the date
property is today and the status property is not `Done`, and shows them in a
`List` — a circle/checkmark glyph, the title, an optional time on the right.
Clicking a row marks it done: the glyph fills and the title strikes through
immediately, then a PATCH goes to Notion. On failure it reverts and beeps.

## Edge Cases
- Zero tasks → "Nothing on deck 🎉".
- No token → error state pointing at Settings.
- Re-opening with a list already loaded doesn't flash the spinner.
- Checking a task removes it from the next fetch (filtered out as Done) — expected.
- Un-checking in the same session restores `originalStatus`, not a guessed value.

## Assumptions
- Database has a title, a date, and a status/select property — names in `Config`.
  Validate by: the user editing `Config.swift` to match their DB.
- < 100 tasks per day. Validate by: fine for personal use; revisit if it bites.

## Open Questions
- Should Done tasks show (greyed, checked) instead of vanishing?
- Sort: currently by `dueTime` then arbitrary. Worth a manual order?

## Notes
Files: `TaskListView.swift` (view + `TaskListModel`), `NotionClient.fetchTodaysTasks`
/ `setDone`, `TodoTask`.
