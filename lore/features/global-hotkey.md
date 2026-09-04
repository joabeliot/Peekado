# Feature: Global toggle hotkey

**Status:** Done

## What It Does
A system-wide hotkey opens the dropdown from any app, and pressing it again (or
clicking away) closes it. Default bind: **⌃⌥⌘Space**. Registered via Carbon's
`RegisterEventHotKey` (`GlobalHotKey.swift`) — works whether or not Peek-A-Do is
focused and needs no Accessibility / Input Monitoring permission.

## Rebinding
Two constants at the top of `AppDelegate`:
```swift
private static let hotKeyCode = kVK_Space
private static let hotKeyModifiers: NSEvent.ModifierFlags = [.control, .option, .command]
```
`kVK_*` codes come from `Carbon.HIToolbox`. No in-app rebind UI (yet — see
`ideas/distributable-app.md`).

## Edge Cases
- ⌥⌘Space alone is macOS's "Finder search" — hence the extra ⌃ in the default.
- If the chosen combo is already a registered system hotkey, `RegisterEventHotKey`
  fails and `GlobalHotKey.init?` returns nil — the hotkey silently doesn't work
  (menu bar click still does). No error surfaced.
- The Carbon C handler can't carry context, so instances are looked up by id in
  `GlobalHotKey.instances`. One handler installed process-wide, guarded by
  `handlerInstalled`.

## Assumptions
- Only ever one hotkey registered. If that changes, the static-table + single
  handler design still holds, but revisit `deinit` ordering.

## Open Questions
- In-app rebind (key recorder)? Deferred — fiddly without a library.
- Show a hint when registration fails?

## Notes
Files: `GlobalHotKey.swift`, `AppDelegate.swift` (`togglePopover`).
