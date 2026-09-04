# Architecture — Overview

A single-target macOS app. No backend of our own; Notion is the datastore.

## Shape

```
PeekADoApp (@main, App)           scene is an empty Settings{} — never shows
  └─ @NSApplicationDelegateAdaptor AppDelegate
       ├─ NSStatusItem            "checklist" button — left-click toggles,
       │                          right-click → Settings… / Quit menu
       ├─ NSPopover (.transient)  hosts TaskListView via NSHostingController
       ├─ NSWindow (lazy)         hosts SettingsView — showSettings()
       └─ DoubleTapMonitor        global NSEvent .flagsChanged monitor →
                                  togglePopover() on double-tap Control

TaskListView (SwiftUI)            gets an onOpenSettings closure from AppDelegate
  ├─ TaskListModel   @MainActor ObservableObject — task state + orchestration
  ├─ AppSettings     @MainActor singleton — [DatabaseProfile] + primaryID,
  │                  token presence, launch-at-login. Persists to UserDefaults;
  │                  mirrors the primary profile into the flat Config.Key.* keys.
  └─ NotionClient    struct, stateless bar the token — the only network code
       └─ KeychainStore   enum — the Notion token, generic-password item

SettingsView (SwiftUI, in the NSWindow) — radio list of DatabaseProfiles
  (add/remove/rename/edit), shared token, Start at login.

Config    enum — reads the mirrored flat keys out of UserDefaults
          (databaseID, {title,date,status}Property) + fixed constants
          (statusPropertyKind, doneStatusValue, newTaskStatusValue, apiVersion)
DatabaseProfile  struct (Codable) — one Notion DB's id + property names
TodoTask         struct — the one task model type
```

`MenuBarExtra` was dropped for `NSStatusItem` + `NSPopover` (no API to
open/close its panel). Settings is a hand-built `NSWindow`, not a SwiftUI
`Settings` scene. See `decisions/nsstatusitem-over-menubarextra.md`,
`decisions/double-tap-toggle.md`, `decisions/settings-window.md`,
`decisions/multi-db-profiles.md`.

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
- **Settings window** (gear, or right-click the icon): edit database profiles
  (each write → `AppSettings` `didSet` → persist JSON + re-mirror the primary
  into the flat keys), radio-select the primary, paste token
  (→ `AppSettings.saveToken` → Keychain), "Start at login" (→ `SMAppService`).
  Switching primary fires `.onChange(of: settings.primaryID)` in an open
  dropdown → `refresh()`.

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
