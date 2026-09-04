# Idea: make Peek-A-Do installable by non-developers

**Captured:** 2026-09-04
**Instinct:** v1 is a personal tool + a clone-and-build repo. "Anyone can open the
repo and install" is *not* true today — it needs Xcode and a hand-edit of
`Config.swift`. If Peek-A-Do is ever handed to non-devs, this is the track.

## Today's gap
- No prebuilt binary. Personal-team builds trip Gatekeeper ("unidentified
  developer" / "damaged").
- No packaging (`.dmg` / Homebrew cask / GitHub Release artifact).
- ~~Database id + property names are compile-time constants~~ — **done**
  2026-09-04: full multi-database config in a Settings window
  (`features/multi-database.md`). `statusPropertyKind` / `doneStatusValue` /
  `newTaskStatusValue` are still global `Config` constants — expose per-profile
  if a real user needs it.
- No in-app hotkey rebind (one constant in `AppDelegate` for now).

## Rough plan (in order of pain)
1. ~~**In-app config.**~~ Done — multi-DB Settings window. Remaining: per-profile
   status constants, and a hotkey key-recorder.
2. **Signing + notarization.** Requires the paid Apple Developer Program
   ($99/yr). Add `codesign --options runtime` + `notarytool submit` + `stapler`
   to `scripts/` (a `release.sh` alongside `install.sh`).
3. **Packaging.** `.dmg` with a drag-to-Applications backdrop, attached to a
   GitHub Release. Optional: a Homebrew cask.
4. **First-run UX.** If launched from outside `/Applications`, offer to move
   itself. Empty-config state should walk the user through creating a Notion
   integration (link out to notion.so/my-integrations) rather than showing an
   error.

## Open questions
- Is distribution even a goal, or is this a personal/Arque-internal tool? If the
  latter, only step 1 is worth doing (nicer setup, no code edit).
- Bundle a "create the Tasks database for me" button (the API call used during
  bring-up) so users don't hand-build the schema?

## Notes
Promote to `features/` and split the tickets if/when this becomes real work.
Ticket: PKD-1.
