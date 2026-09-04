# Hand-written Xcode project

**Date:** 2026-09-04
**Status:** Decided

## Decided
`PeekADo.xcodeproj/project.pbxproj` is authored by hand at `objectVersion 77`
using a single `PBXFileSystemSynchronizedRootGroup` pointing at `PeekADo/`.

## Why
- No Xcode GUI available in the build environment; the project had to be created
  from files alone.
- `xcodegen` / `tuist` weren't installed and adding a build-tool dependency cut
  against the "native only" principle.
- Synchronized groups (Xcode 16+) mean the pbxproj doesn't enumerate sources —
  any `.swift` dropped in `PeekADo/` is picked up automatically. That makes a
  hand-written project robust to file changes.

## Rejected
- **XcodeGen / a `project.yml`** — extra tool, extra install step.
- **Swift Package executable target** — awkward to get an `LSUIElement` app
  bundle + Info.plist keys + code signing the way a real `.app` needs.
- **Generating in Xcode once, by hand** — not possible without the GUI.

## Consequences
- Adding source files: just put them in `PeekADo/`. No pbxproj edit.
- Adding a **test target** or resources/asset catalog: needs a manual pbxproj
  extension, or a one-time regenerate in Xcode.
- `INFOPLIST_KEY_*` build settings are the only Info.plist surface
  (`GENERATE_INFOPLIST_FILE = YES`).
