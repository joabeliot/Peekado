# Architecture — Overview

A single-target macOS app. No backend of our own; Notion is the datastore.

## Shape

```
PeekADoApp (@main, App)
  └─ MenuBarExtra  ── style .window, systemImage "checklist", LSUIElement
       └─ TaskListView (SwiftUI)
            ├─ TaskListModel   @MainActor ObservableObject — all state + orchestration
            └─ NotionClient    struct, stateless bar the token — the only network code
                 └─ KeychainStore   enum — the Notion token, generic-password item

Config   enum of constants — database id, property names, status kind, API version
TodoTask struct — the one model type
```

## Flow

- **Open dropdown → `TaskListView.onAppear` → `model.refresh()`**
  `NotionClient.fetchTodaysTasks()` → `POST /v1/databases/{id}/query` filtered on
  `Due == today` only (Done included) → parse `results` → `TaskListModel.ordered`
  (open first by time, done last) → `phase = .loaded([...])`. Spinner only shows
  when there's nothing already on screen. Footer shows `model.summary` ("X of Y done").
- **Toggle a row → `model.toggle` flips `done` locally → `.loaded` re-emitted →
  `NotionClient.setDone()` → `PATCH /v1/pages/{id}`.** On error: revert + beep.
  Rows with a `temp-` id (not yet saved) ignore toggles.
- **Add field submit → `model.addTask` inserts an optimistic `temp-` row →
  `NotionClient.createTask()` → `POST /v1/pages` (Due = today, Status =
  `Config.newTaskStatusValue`) → `refresh()` swaps in server truth.** On error:
  drop the temp row + beep.
- **Settings popover** (gear): paste token → `KeychainStore.saveToken` → refresh.
  "Start at login" → `SMAppService.mainApp.register()/unregister()`.

## State machine (`TaskListModel.Phase`)

`idle → loading → loaded([TodoTask]) | failed(String)`
`loaded([])` renders the empty state. `failed` renders the message + a warning glyph.

## Distribution

No sandbox. Hardened runtime on. Signed with a personal-team Apple Development
cert. Runs from `/Applications`; `SMAppService` registers the main app (not a
helper) as the login item.

## Deliberately absent

Background polling, notifications, caching/persistence, multi-day views,
settings for the database id / property names (code constants for now).
Reordering the list on toggle (only on refresh — checking a box strikes it
through in place).
