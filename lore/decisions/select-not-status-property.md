# Use a Select property, not a Status property

**Date:** 2026-09-04
**Status:** Decided

## Decided
Peek-A-Do's completion field is a Notion **Select** property, and
`Config.statusPropertyKind` defaults to `.select`. The `.status` case still
exists in code for anyone whose DB already uses a real Status property (read +
toggle work), but the shipped/tested path is Select.

## Why
The Notion API cannot *create* a Status property — only the Notion UI can.
Peek-A-Do creates its database and tasks from code (bring-up + the add-task
feature), so the field it manages has to be one the API can write. Select does
everything needed: named options, `does_not_equal` filter, `{name:}` on PATCH.

## Rejected
- **Status property** — can't be created via API; `createTask` and any
  "provision the DB" flow would half-work.
- **A Checkbox property** — loses the "In progress" middle state and the
  `does_not_equal "Done"` filter phrasing.

## Consequences
- `Config.statusPropertyKind` must match the user's actual property type or
  every call 400s. It's the most common misconfiguration.
- `NotionClient` branches on `statusPropertyKind.rawValue` (`"status"` /
  `"select"`) for both the query filter key and the PATCH body key.
