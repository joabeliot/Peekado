# Peek-a-do

A macOS menu bar utility that shows today's Notion tasks in a dropdown.
No Dock icon, no window — just a checklist glyph in the menu bar.

- **Platform:** macOS 13+ (built with Xcode 26, SwiftUI + AppKit)
- **Dependencies:** none — native `URLSession`, `Security`, `ServiceManagement` only
- **Bundle id:** `app.arque.peekado`

## What it does

- Checklist icon in the menu bar → click it, **or double-tap Control anywhere** →
  opens/closes an inline task list popover.
- Fetches all tasks from a Notion database due **today** (Done included). Open
  tasks first, completed struck through and sorted last. Footer shows "X of Y done".
- Type in the field at the top + Return to **add a task** straight to Notion
  (Due = today). Optimistic, rolls back on failure.
- Click a row to mark it done — optimistic, then `PATCH` to Notion, rolls back
  with a beep on failure.
- Refreshes every time you open it. No background polling.
- **Multiple databases** — add several in Settings, radio-select which is
  primary; the primary opens by default and you can switch anytime.
- Gear (or right-click the icon) → Settings **window**: databases, integration
  token, "Start at login".

## Files

| File | Role |
| --- | --- |
| `PeekADo/PeekADoApp.swift` | `@main` — hands off to `AppDelegate` |
| `PeekADo/AppDelegate.swift` | Menu bar item, popover, Settings window, toggle gesture |
| `PeekADo/DoubleTapMonitor.swift` | Global monitor: double-tap a modifier |
| `PeekADo/AppSettings.swift` | `[DatabaseProfile]` + primary + token + login, ↔ `UserDefaults` |
| `PeekADo/DatabaseProfile.swift` | One database's id + property names |
| `PeekADo/SettingsView.swift` | The Settings window UI |
| `PeekADo/Config.swift` | Reads the mirrored flat keys + fixed constants |
| `PeekADo/TaskModel.swift` | `TodoTask` value type |
| `PeekADo/KeychainStore.swift` | Notion token in the Keychain |
| `PeekADo/NotionClient.swift` | `URLSession` calls: query database, patch/create page |
| `PeekADo/TaskListView.swift` | The dropdown UI + its view model |

## Setup

### 1. Create a Notion integration

1. <https://www.notion.so/my-integrations> → **New integration** (internal).
2. Copy the **Internal Integration Secret** (`secret_…` or `ntn_…`).
3. Open your task database in Notion → **••• → Connections →** add the integration.
   (Without this the API returns 404 for the database.)

### 2. Build & run

```sh
open PeekADo.xcodeproj      # Signing: personal team, or "Sign to Run Locally"
# ⌘R — no window; look for the checklist icon in the menu bar
```

or, for a standalone install to `/Applications`:

```sh
scripts/install.sh
```

### 3. Configure it (in the app)

Click the icon → **gear** (opens the Settings window):

- Under **Databases**, fill the first row: a **name**, the **Database ID** (from
  the URL `notion.so/<workspace>/<DATABASE_ID>?v=…`), and your **Name / Due /
  Status** property names. Add more rows with **+**; the radio button picks the
  primary (the one that opens).
- Paste the **integration token** from step 1 (shared by all databases).

Stored per-user — token in Keychain, profiles as JSON in `UserDefaults`, nothing
compiled in. If a status field isn't a Select, or "done" isn't called `Done`,
change `statusPropertyKind` / `doneStatusValue` in `Config.swift` (these are
global, not per-database).

### Build settings — already set

- `INFOPLIST_KEY_LSUIElement = YES` — menu bar only, no Dock icon
- `ENABLE_HARDENED_RUNTIME = YES`, App Sandbox **off** (personal utility)
- Rebind the toggle: `toggleModifier` at the top of `AppDelegate.swift`
  (needs Accessibility permission — the app prompts on first launch)

## Not done yet

- Background refresh / notifications
- Multiple dates ("this week"), manual ordering
- Quick-switch the primary database from the menu bar icon (Settings only for now)
- Per-database status type / "done" value (currently global in `Config.swift`)
- Signed + notarized build for non-developers (see `lore/ideas/distributable-app.md`)
- In-app hotkey rebind
