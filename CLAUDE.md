# Peek-A-Do

macOS menu bar app (SwiftUI `MenuBarExtra`, `LSUIElement`) that shows today's
Notion tasks in a dropdown and lets you add them without opening Notion.

- **Stack:** Swift 5 / SwiftUI + AppKit, native only (`URLSession`, `Security`,
  `ServiceManagement`). No third-party packages. macOS 13+.
- **Datastore:** a Notion database, via the Notion REST API. No backend of our own.
- **Bundle id / Keychain service:** `app.arque.peekado`.

## Session Rule

`lore/` is the source of truth. Every session:

1. **Start:** read `lore/INDEX.md` → `lore/GUARDRAILS.md` → `lore/CONTEXT.md`.
   Load Tier 2 files (`lore/architecture/`, `lore/features/`, `lore/decisions/`,
   `lore/testing/`) only as the task needs them — name which you loaded.
2. **During:** keep tickets current (`lore ticket …`), log decisions to
   `lore/decisions/` as you make them, fix stale lore as you find it.
3. **End:** rewrite the `CONTEXT.md` header, append a log entry, update feature /
   testing / decision files that changed, and **commit `lore/` with the code**.

Never touch `lore/OG.md` or `lore/MISSION.md` — human-only.

## lore Index

| File | Load when |
|---|---|
| `lore/GUARDRAILS.md` | always |
| `lore/CONTEXT.md` | always — current state + session log |
| `lore/architecture/overview.md` | changing app structure or the fetch/write flow |
| `lore/architecture/models.md` | touching `TodoTask` or Notion JSON parsing |
| `lore/architecture/apis.md` | changing a Notion API call |
| `lore/features/*.md` | working on that feature |
| `lore/decisions/*.md` | making or revisiting a significant decision |
| `lore/testing/registry.md` | writing or reviewing tests |

## Build

```sh
# verify a change compiles
xcodebuild -project PeekADo.xcodeproj -scheme PeekADo -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

# dev loop: open in Xcode, ⌘R — app has no window, look in the menu bar
open PeekADo.xcodeproj

# ship standalone: build Release + install to /Applications
scripts/install.sh
```

New Swift files just go in `PeekADo/` — the Xcode project syncs the folder, no
`pbxproj` edit needed. See `lore/decisions/hand-written-xcodeproj.md`.
