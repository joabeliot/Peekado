# Feature: Double-tap to toggle

**Status:** Done

## What It Does
Double-tap **Control** anywhere to open the dropdown; double-tap again (or click
away) to close — the "double-tap ⌘ for Siri" gesture. `DoubleTapMonitor.swift`:
a global `NSEvent` monitor on `.flagsChanged` that fires when the modifier goes
down twice within 0.4s with nothing else pressed in between.

Menu bar icon click always works too, and is the fallback when the gesture
isn't available.

## Rebinding
One constant in `AppDelegate`:
```swift
private static let toggleModifier: NSEvent.ModifierFlags = .control
```
`.command` / `.option` also work. No in-app rebind UI.

## Permission
Global modifier monitoring needs the app to be **trusted for Accessibility**.
`AppDelegate.applicationDidFinishLaunching` calls
`AXIsProcessTrustedWithOptions([AXTrustedCheckOptionPrompt: true])`, which pops
the system dialog on first launch. Until the user adds Peek-A-Do under
System Settings › Privacy & Security › Accessibility and toggles it on, the
gesture silently does nothing.

## Edge Cases
- A reinstall (new binary, same bundle id + cert) *usually* keeps the grant, but
  macOS sometimes drops it and the user must re-toggle.
- Any real keypress or mouse click between taps resets the sequence — no false
  fire while typing.
- Caps Lock / Fn are masked out of the comparison; other modifiers held with
  Control cancel the run.
- No event is consumed — other apps still see the Control taps.

## Rejected
- **Carbon `RegisterEventHotKey` chord** (was the first cut, `GlobalHotKey.swift`,
  now deleted). No permission needed, but 3–4 keys and it silently failed when
  the combo was already registered by another app. See
  `decisions/double-tap-toggle.md`.

## Open Questions
- Surface a hint in Settings when Accessibility isn't granted?
- In-app modifier picker?

## Notes
Files: `DoubleTapMonitor.swift`, `AppDelegate.swift` (`togglePopover`,
the `AXIsProcessTrustedWithOptions` prompt).
