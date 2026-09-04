# NSStatusItem + NSPopover instead of MenuBarExtra

**Date:** 2026-09-04
**Status:** Decided (supersedes the MenuBarExtra note in earlier decisions)

## Decided
The menu bar item is an `NSStatusItem` with a `.transient` `NSPopover` that hosts
`TaskListView` via `NSHostingController`, all owned by an `AppDelegate` wired in
with `@NSApplicationDelegateAdaptor`. The SwiftUI `App` has only an empty
`Settings {}` scene (never shown, keeps SwiftUI happy).

## Why
The ask was a global hotkey that opens *and closes* the dropdown (Siri-style).
`MenuBarExtra` exposes no way to open or close its panel from code — you can only
change whether the icon exists. `NSPopover` has `show(relativeTo:)` /
`performClose(_:)` and `isShown`, which is exactly the toggle primitive needed.

## Rejected
- **Keep `MenuBarExtra`, fake the toggle** — no supported hook; the private
  route (`NSStatusItem` off the internal window) is fragile across OS versions.
- **A separate hotkey-only helper window** — two surfaces showing the same list,
  more state to keep in sync.

## Consequences
- `AppDelegate` now owns lifecycle: status item, popover, `GlobalHotKey`.
- Visual: a popover with an arrow to the menu bar, vs the old detached rounded
  panel. Close enough; standard for this class of app.
- Popover must be made key on show (`view.window?.makeKey()`) or text fields
  won't accept input.
- `NSHostingController.sizingOptions = [.preferredContentSize]` lets the popover
  follow the view's height; `TaskListView` still pins `width: 320`.
