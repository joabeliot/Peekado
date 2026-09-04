# Double-tap modifier to toggle, not a chord

**Date:** 2026-09-04
**Status:** Decided (supersedes the Carbon-chord approach)

## Decided
The dropdown is toggled by **double-tapping Control** (`DoubleTapMonitor`), a
global `NSEvent` `.flagsChanged` monitor. The menu bar click is the always-on
fallback.

## Why
The first cut was a Carbon `RegisterEventHotKey` chord (⌃⌥⌘Space). Two problems
in practice:
- 3–4 keys is a lot for something you hit all day.
- `RegisterEventHotKey` fails silently if the combo is already registered by
  another running app — the user just sees nothing happen, with no way to tell
  why. That's exactly what happened.

A double-tap of a single modifier is one finger, near-impossible to collide with,
and matches a gesture people already know (double-tap ⌘ → Siri).

## Rejected
- **Carbon chord** — above. `GlobalHotKey.swift` deleted; recoverable from git if
  a no-permission option is ever needed again.
- **Configurable chord with an in-app recorder** — more UI, still collision-prone.

## Consequences
- Needs **Accessibility** permission (global modifier monitoring). `AppDelegate`
  prompts on launch; the gesture is dead until the user grants it. This is the
  real cost of the choice.
- Slightly less deterministic than a registered hotkey — a tap can be missed if
  timing is off. Acceptable; the click always works.
- Reinstalls can drop the Accessibility grant (macOS TCC keyed on the binary).
