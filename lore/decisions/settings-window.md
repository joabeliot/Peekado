# Settings is a real window, hosted by AppDelegate

**Date:** 2026-09-04
**Status:** Decided

## Decided
Settings moved out of the popover into a proper `NSWindow` (titled, closable),
created lazily in `AppDelegate.showSettings()` with
`contentViewController = NSHostingController(rootView: SettingsView())` and
`isReleasedWhenClosed = false`. Reached from the popover's gear button (a
`onOpenSettings` closure injected into `TaskListView`) or a right-click menu on
the menu bar icon.

## Why
- The multi-database list (radio + name + 4 fields per row, add/remove) doesn't
  fit a 320-pt popover.
- `AppDelegate` already owns the AppKit surface (status item, popover). Adding
  one more `NSWindow` there is consistent and fully under our control.

## Rejected
- **SwiftUI `Settings { SettingsView() }` scene** — opening it from code needs
  `showSettingsWindow:` / `showPreferencesWindow:`, whose selector changed
  between macOS 13 and 14. Fragile for an `LSUIElement` app with no app menu.
- **`@Environment(\.openWindow)` from the popover** — the popover's
  `NSHostingController` is created by hand and isn't guaranteed to carry the
  scene environment, so `openWindow` can be a silent no-op.

## Consequences
- `PeekADoApp`'s `body` keeps a throwaway `Settings { EmptyView() }` scene just
  to satisfy `App`; the real window is the AppKit one.
- `TaskListView` lost its inline settings panel and `showingSettings` state.
- Closing the settings window doesn't quit (LSUIElement, no windows required).
