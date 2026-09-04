# Architecture — Overview

A single-target macOS app. No backend of our own; Notion is the datastore.

## Shape

```
PeekADoApp (@main, App)           scene is an empty Settings{} — never shows
  └─ @NSApplicationDelegateAdaptor AppDelegate
       ├─ NSStatusItem            the "checklist" menu bar button
       ├─ NSPopover (.transient)  hosts TaskListView via NSHostingController
       └─ DoubleTapMonitor        global NSEvent .flagsChanged monitor →
                                  togglePopover() on double-tap Control

TaskListView (SwiftUI)
  ├─ TaskListModel   @MainActor ObservableObject — all task state + orchestration
  ├─ AppSettings     @MainActor singleton ObservableObject — UI mirror of the
  │                  UserDefaults config keys; Settings-panel bindings
  └─ NotionClient    struct, stateless bar the token — the only network code
       └─ KeychainStore   enum — the Notion token, generic-password item

Config    enum — reads the Settings-backed values out of UserDefaults
          (databaseID, {title,date,status}Property) + fixed constants
          (statusPropertyKind, doneStatusValue, newTaskStatusValue, apiVersion)
TodoTask  struct — the one model type
```

`MenuBarExtra` was dropped for `NSStatusItem` + `NSPopover` because it has no
API to open/close its panel — the toggle gesture needs that. See
`decisions/nsstatusitem-over-menubarextra.md` and `decisions/double-tap-toggle.md`.

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
- **Toggle (double-tap Control, or click the menu bar icon) → `AppDelegate.togglePopover`.**
  Shown → `performClose`. Hidden → `NSApp.activate` + `popover.show(relativeTo:)`
  + make the popover window key so its text fields take input.
- **Settings panel** (gear): edit `databaseID` + property names (→ `AppSettings.save`
  → UserDefaults), paste token (→ `KeychainStore.saveToken`), "Start at login"
  (→ `SMAppService`). "Save" persists all of it and calls `refresh()`.

## State machine (`TaskListModel.Phase`)

`idle → loading → loaded([TodoTask]) | failed(String)`
`loaded([])` renders the empty state. `failed` renders the message + a warning glyph.

## Distribution

No sandbox. Hardened runtime on. Signed with a personal-team Apple Development
cert. Runs from `/Applications`; `SMAppService` registers the main app (not a
helper) as the login item. The double-tap gesture needs Accessibility
permission (prompted on launch); no entitlement.

## Deliberately absent

Background polling, notifications, caching/persistence, multi-day views.
Reordering the list on toggle (only on refresh — checking a box strikes it
through in place). In-app rebind of the toggle modifier.
