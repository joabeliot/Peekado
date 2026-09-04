# Show Done tasks instead of filtering them out

**Date:** 2026-09-04
**Status:** Decided

## Decided
`fetchTodaysTasks()` filters on the date property only. Done tasks come back,
render checked + struck through, and sort to the bottom of the list. The footer
shows "X of Y done".

## Why
The ask was a completed-count in the footer. With the old server-side
`Status != Done` filter, finished tasks vanished on the next refresh, so any
count would reset to `0 of N` constantly — the number people actually want
("3 of 5 done today") was impossible to show.

Bonus: the old behaviour ("task disappears the moment you check it") was mildly
disorienting. Keeping the row visible is calmer.

## Rejected
- **Count only within the current in-memory list** (keep the filter). Cheap, but
  the count is meaningless after a refresh — defeats the point.
- **A second "count" API call** for Done-today. Extra request, more latency, more
  failure surface, for a number we can derive from data we already fetch.

## Consequences
- Up to 100 tasks/day now includes completed ones — still unpaginated, still fine
  for personal use.
- `TaskListModel.ordered` groups open-before-done; the list only re-sorts on
  refresh, so checking a box doesn't make the row jump.
- Un-checking a task that was Done at fetch time has no real prior value →
  `toggle` falls back to `Config.newTaskStatusValue`.
