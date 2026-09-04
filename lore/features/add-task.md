# Feature: Add task from the dropdown

**Status:** Done

## What It Does
A text field at the top of the dropdown. Type a title, press Return: an
optimistic row appears instantly with a `temp-` id, a `POST /v1/pages` creates
the page in the database (Due = today, Status = `Config.newTaskStatusValue`),
then a refresh swaps the temp row for Notion's real one. Focus stays in the
field so several tasks can be added in a row. A small spinner shows while the
write is in flight.

## Edge Cases
- Empty / whitespace-only input → ignored.
- No token → drops to the error state instead of posting.
- POST fails → the temp row is removed and it beeps.
- `Config.newTaskStatusValue == ""` → the page is created with no status set.
- A `temp-` row can't be toggled done until the refresh replaces it.

## Assumptions
- The status/select option named by `newTaskStatusValue` exists in the DB.
  Validate by: user config; a bad name makes Notion 400 and the row rolls back.

## Open Questions
- Let the user pick a due date other than today?
- Inline errors instead of just a beep?

## Notes
Files: `TaskListView` (`addField`, `submitNewTask`, `TaskListModel.addTask`),
`NotionClient.createTask`.
