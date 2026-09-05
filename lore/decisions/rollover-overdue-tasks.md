# Rollover overdue incomplete tasks to today

**Date:** 2026-09-05
**Status:** Decided

## Decided
1. `NotionClient.fetchTodaysTasks()` queries Notion with a compound `or` filter retrieving:
   - All tasks due today (including Done, so the footer can accurately report today's completion count).
   - Incomplete tasks (status != Done, or status is empty) from the past 7 days (`on_or_after: 7 days ago` AND `before: today`).
2. Past Done tasks are excluded so they do not clutter today's dropdown or skew today's "X of Y done" count.
3. For any past incomplete tasks returned, their Due date in Notion is updated to today (`PATCH /v1/pages/{id}`) asynchronously in the background.
4. Any time-of-day component on the original task is preserved when updating the date.

## Why
When tasks were created on previous days (e.g. Sept 4) and left incomplete (in-progress or to-do), opening Peek-A-Do the following day (Sept 5) would report "Nothing on deck 🎉" because the query strictly matched `date == today`. Incomplete tasks silently disappeared from view.

Updating the date to today in Notion ensures:
- Overdue tasks are surfaced immediately to the user in today's dropdown.
- Notion stays in sync (tasks are actually rescheduled for today on the board/calendar).
- Past completed tasks remain in their historical date in Notion without being pulled forward.

## Rejected
- **Displaying overdue tasks without updating Notion**: Leaves tasks overdue on the Notion database view, requiring manual date adjustments in Notion.
- **Unbounded overdue lookback**: Querying all past tasks without a time window could fetch hundreds of ancient/abandoned tasks, flooding the dropdown and triggering Notion API rate limits (3 req/sec). A 7-day lookback window provides a sensible balance.
- **Synchronous date PATCHing before rendering**: Would add round-trip latency to opening the popover. Instead, tasks render instantly, and Notion is patched in the background.

## Consequences
- Overdue incomplete tasks from the last 7 days appear in the dropdown grouped by status (To do → In progress → Done) and count towards today's total task pool.
- Background date updates to Notion are non-blocking and best-effort.
