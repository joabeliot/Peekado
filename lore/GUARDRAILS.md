# Guardrails

## Always
- Keep it to native frameworks only — SwiftUI, AppKit, `URLSession`, `Security`,
  `ServiceManagement`. No third-party packages.
- Secrets (the Notion token) go in the Keychain via `KeychainStore`. Never
  `UserDefaults`, never a file, never a source constant.
- Runtime config is `[DatabaseProfile]` + `primaryID` in `AppSettings`, stored
  as JSON in `UserDefaults` (`notion.profiles` / `notion.primaryProfileID`).
  `AppSettings.persist()` is the **only** writer of the flat `Config.Key.*`
  keys — it mirrors the primary profile there so `Config` / `NotionClient`
  (off-main-actor) keep reading them unchanged. Don't write `Config.Key.*`
  from anywhere else, and don't make `Config` depend on `AppSettings`.
- `statusPropertyKind` / `doneStatusValue` / `newTaskStatusValue` /
  `notionAPIVersion` are still global `Config` constants — edited in source.
- Nothing real lands in git — `Config`'s defaults are generic, ids live only in
  UserDefaults.
- All UI state changes happen on the main actor. `TaskListModel` is `@MainActor`.
- Network writes are optimistic: update the UI first, call Notion, roll back +
  `NSSound.beep()` on failure.
- After any code change, run a build before calling it done:
  `xcodebuild -project PeekADo.xcodeproj -scheme PeekADo -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- Commit `lore/` changes alongside the code they describe.

## Never
- Never commit a real Notion database id, page id, token, or workspace name —
  not in source, not in a commit message.
- Never add a Dock icon or a main window. This is `LSUIElement = YES`, menu bar only.
- Never block the main thread on a Keychain or network call — wrap in `Task`.
- Never create a Notion **Status** property from code — the API can't. Use Select.
- Never rename `TodoTask` back to `Task` (collides with Swift concurrency).

## Conventions
- Bundle id / Keychain service: `app.arque.peekado`.
- Deployment target: macOS 13.0. Swift language version 5.
- Menu bar is `NSStatusItem` + `NSPopover` in `AppDelegate` — **not**
  `MenuBarExtra` (it can't be toggled from code). Don't reintroduce it.
- Settings is an `NSWindow` built in `AppDelegate.showSettings()`, not a SwiftUI
  `Settings` scene. `TaskListView` reaches it via the injected `onOpenSettings`.
- The toggle is double-tap Control (`DoubleTapMonitor`), rebind via
  `toggleModifier` in `AppDelegate`. Needs Accessibility permission.
- One type per concern. Resist splitting further.
- Xcode project is hand-written (`objectVersion 77`, file-system synchronized
  group). Adding a file to `PeekADo/` is enough — no pbxproj edit needed.
- Property-name and status-value assumptions are all funnelled through `Config`.

## Build / Run
- Dev loop: open `PeekADo.xcodeproj`, ⌘R. App has no window — look in the menu bar.
- Standalone: build Release, copy `PeekADo.app` to `/Applications`, launch it,
  flip "Start at login" in the app's Settings. `scripts/install.sh` does the copy.
- Signing: automatic, personal team, "Sign to Run Locally" also fine.
