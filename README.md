# Peek-a-do

A macOS menu bar utility that shows today's Notion tasks in a dropdown.
No Dock icon, no window — just a checklist glyph in the menu bar.

- **Platform:** macOS 13+ (built with Xcode 26, SwiftUI `MenuBarExtra`)
- **Dependencies:** none — native `URLSession` only
- **Bundle id:** `app.arque.peekado`

## What it does (v1)

- Checklist icon in the menu bar → click opens an inline task list (`.window` style).
- Fetches tasks from a Notion database where the date property is **today** and
  the status property is **not Done**.
- Type in the field at the top + Return to **add a task** straight to Notion
  (Due = today, Status = `Config.newTaskStatusValue`). Optimistic, rolls back on failure.
- Click a row to mark it done — optimistic UI update, then `PATCH` to Notion,
  rolls back with a beep if the write fails.
- Refreshes every time you open the dropdown. No background polling.
- Loading state on first fetch; empty state ("Nothing on deck 🎉") when clear.
- Bottom bar: **Refresh** and **Quit**. Gear icon → paste your Notion token.

## Files

| File | Role |
| --- | --- |
| `PeekADo/PeekADoApp.swift` | App entry — the `MenuBarExtra` scene |
| `PeekADo/Config.swift` | **Edit this** — database id + property names |
| `PeekADo/TaskModel.swift` | `TodoTask` value type |
| `PeekADo/KeychainStore.swift` | Stores the Notion token in the Keychain |
| `PeekADo/NotionClient.swift` | `URLSession` calls: query database, patch page |
| `PeekADo/TaskListView.swift` | The dropdown UI + its view model |

## Setup — do this before it works

### 1. Create a Notion integration

1. Go to <https://www.notion.so/my-integrations> → **New integration** (internal).
2. Copy the **Internal Integration Secret** (starts with `secret_` or `ntn_`).
3. Open your task database in Notion → **••• → Connections →** add your integration.
   (Without this the API returns 404 for the database.)

### 2. Fill in `PeekADo/Config.swift`

```swift
static let databaseID   = "…"      // the 32-hex id from your database URL
static let titleProperty  = "Name"   // your title property
static let dateProperty   = "Due"    // your date property
static let statusProperty = "Status" // your status/select property
static let statusPropertyKind: StatusKind = .status  // .status or .select
static let doneStatusValue = "Done"
```

Getting the database id: open the database as a full page, the URL looks like
`notion.so/<workspace>/<DATABASE_ID>?v=<view_id>` — you want `<DATABASE_ID>`.

### 3. Build & run

```sh
open PeekADo.xcodeproj
```

- In **Signing & Capabilities**, pick your personal team (automatic signing).
- Run (⌘R). The app has no window — look for the checklist icon in the menu bar.
- Click it → gear icon → paste your integration secret → **Save**.

### Info.plist / build settings — already set for you

These live in the target's build settings (Xcode generates the Info.plist):

- `INFOPLIST_KEY_LSUIElement = YES` — menu bar only, no Dock icon
- `ENABLE_HARDENED_RUNTIME = YES`, App Sandbox left **off** (personal utility;
  turn it on later and add the *Outgoing Connections (Client)* entitlement if you
  want to sandbox it)

## Not in v1 (later)

- Background refresh / notifications
- Multiple dates ("this week"), sections, sorting controls
- Settings window for the database id + property names (currently code constants)
