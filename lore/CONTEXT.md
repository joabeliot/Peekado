# Context

**Focus:** v1 in daily use, growing on request. Just shipped multi-DB + a real Settings window.
**Phase:** Alpha (personal daily driver)
**Open:** JB to confirm double-tap toggle (needs Accessibility grant) + the new Settings window + multi-DB. PKD-1 (distributable) — backlog. No tests. No CHANGELOG hook. `OG.md` + `MISSION.md` unwritten.
**Next:** Nothing scheduled. Possible: quick-switch primary from the menu bar icon; per-profile status config.

---

## Log

### 2026-09-04 — JB / claude-code
Built the whole v1 in one session. Menu bar app (`MenuBarExtra`, `.window`,
`LSUIElement`) that queries a Notion database for today's non-Done tasks over
`URLSession`, renders them in a `List` with an optimistic done-toggle (PATCH
write-back + rollback), an inline "add task" field (POST `/v1/pages`), and a
"Start at login" toggle (`SMAppService`). Token in Keychain via a Settings
popover. Verified end-to-end against a live Notion workspace, then installed the
signed Release build to `/Applications`.
Loaded: none (greenfield).
Left open: tests, CHANGELOG hook, v2 scope.
Carry forward: repo history was rewritten to strip the real database id +
workspace name before it could be shared. Config ships with placeholders.

### 2026-09-04 (later) — JB / claude-code
Scaffolded `lore/` (shorthand PKD) + project `CLAUDE.md` + `scripts/install.sh`.
Renamed bundle id to `app.arque.peekado`. Collapsed git history to one clean
"Peek-A-Do v1" commit and force-pushed (verified 0 secret/identifier leaks
across all objects). JB rotated the Notion token — re-pasted the new one into
the `/Applications` app via the gear. App confirmed working with his real tasks.
Logged idea `distributable-app.md` + ticket PKD-1 for a future "non-devs can
install it" track (in-app config → notarization/$99 → packaging). Parking here.
Loaded: none.
Left open: PKD-1 (backlog), tests, CHANGELOG hook.
Carry forward: v1 is a personal daily driver + clone-and-build repo; not a
download-and-run app yet. Don't reopen unless it breaks or distribution is on.

### 2026-09-04 (later still) — JB / claude-code
Footer now shows "X of Y done". To make that meaningful, `fetchTodaysTasks`
stopped filtering out Done — completed tasks now render checked, sorted to the
bottom (`TaskListModel.ordered`), and no longer vanish on check. Un-check has a
`newTaskStatusValue` fallback. Decision: `decisions/show-done-tasks.md`.
Loaded: `architecture/apis.md`, `architecture/overview.md`, `features/task-list.md`.
Left open: unchanged (PKD-1, tests, CHANGELOG hook).

### 2026-09-04 (cont.) — JB / claude-code
Fixed `scripts/install.sh` (brace `${VAR}`, ASCII only — `set -u` choked on a
multibyte char abutting `$DEST`). Then the standalone build 404'd because
`Config.databaseID` was the placeholder from the history scrub: briefly split it
into `LocalConfig.swift` + skip-worktree.
Loaded: `GUARDRAILS.md`.

### 2026-09-04 (cont.) — JB / claude-code
Big one. (a) Global toggle hotkey: `GlobalHotKey.swift` (Carbon
`RegisterEventHotKey`, no permission), default ⌃⌥⌘Space, opens/closes the
dropdown from anywhere. (b) To make that possible, replaced `MenuBarExtra` with
`AppDelegate` + `NSStatusItem` + `NSPopover` (`decisions/nsstatusitem-over-menubarextra.md`).
(c) `databaseID` + property names moved from source into the Settings panel /
UserDefaults (`AppSettings.swift`, `features/settings-config.md`);
`LocalConfig.swift` deleted, skip-worktree gone. Migrated JB's real id into the
app's UserDefaults via `defaults write`. Build green, installed.
Loaded: `architecture/{overview,apis}.md`, `GUARDRAILS.md`, `ideas/distributable-app.md`,
`decisions/token-in-keychain.md`.
Left open: JB confirms hotkey+popover feel right; PKD-1.

### 2026-09-04 (cont.) — JB / claude-code
The ⌃⌥⌘Space chord did nothing for JB — almost certainly already registered by
another app (`RegisterEventHotKey` fails silently). Swapped it for
**double-tap Control** (`DoubleTapMonitor` — global `.flagsChanged` monitor,
`decisions/double-tap-toggle.md`). `GlobalHotKey.swift` deleted. Trade-off: needs
Accessibility permission; `AppDelegate` prompts on launch, menu bar click is the
fallback. Built + installed. JB needs to grant Accessibility, then test.
Loaded: `architecture/{overview,apis}.md`, `GUARDRAILS.md`, `features/global-hotkey.md`.

### 2026-09-04 (cont.) — JB / claude-code
Multi-database. `DatabaseProfile` (Codable: name + db id + property names);
`AppSettings` rebuilt around `[DatabaseProfile]` + `primaryID`, JSON in
UserDefaults, mirrors the primary into the flat `Config.Key.*` keys so
`Config`/`NotionClient` are untouched (`decisions/multi-db-profiles.md`). Old
single flat config auto-migrates to one profile on launch (verified on JB's
install → "My tasks"). Settings became a real `NSWindow` hosted by `AppDelegate`
(`decisions/settings-window.md`) with a radio-select profile list; the inline
popover panel is gone. Right-click the menu bar icon → Settings…/Quit. Token +
launch-at-login moved from `TaskListModel` to `AppSettings`. Build green, installed.
Loaded: `architecture/{overview,models,apis}.md`, `GUARDRAILS.md`,
`features/settings-config.md`, `ideas/distributable-app.md`.
Left open: JB tries it; quick-switch from the icon; per-profile status config.

### 2026-09-04 (cont.) — JB / claude-code
"Paste an id, tool sets up the rest." `NotionClient.fetchDatabaseSchema` (static,
`GET /v1/databases/{id}`) guesses title/date/status property + status kind +
done/to-do option names; `SettingsView` has an "Add & set up" field + per-row
"Re-detect" and an "Edit" disclosure for manual override. `DatabaseProfile`
gained `statusKind`/`doneValue`/`newTaskValue` (lenient decoder for old data);
`Config`'s status constants are now computed from mirrored flat keys. Built +
installed. Not live-tested (JB rotated the token; can't curl).
Loaded: `architecture/{apis,models}.md`, `GUARDRAILS.md`, `features/multi-database.md`,
`decisions/multi-db-profiles.md`.
Left open: JB tests detection against a real DB.

### 2026-09-04 (cont.) — JB / claude-code
Settings became tabbed (Databases / Notion / General — `TabView`, fixed 480×540).
JB tested auto-detect: "Stablish" DB detected clean; a second DB failed with
"no date property" (genuinely has none) but the row still showed a fake
Name·Due·Status recap. Fixed: `addProfile(databaseID:)` is sync + returns the id,
the view runs the same per-row `detect` so the error lands on the row and expands
it; the summary line now shows the error / "not set up" when the profile isn't
really configured. Installed.
Loaded: none.

### 2026-09-04 (cont.) — JB / claude-code
JB hit the URL confusion: pasted the `?v=` view id (404), then found his empty
"New database" (only a Name column → "no date property"). Added
`NotionClient.canonicalDatabaseID` — accepts a full pasted Notion URL / dashed
UUID / bare id, strips the `?v=` view id, used on detect+query+create and stored
back on the profile. Schema-fetch 404 now reads friendly instead of raw JSON.
Told JB: his first id was right; that DB just needs a Date + Status column in Notion.
Loaded: none.
Left open: JB adds Date/Status props to the new DB and re-detects.

### 2026-09-04 (cont.) — JB / claude-code
In-progress (and arbitrary) task statuses now surface in the dropdown:
half-filled orange circle + "IN PROGRESS" badge; any other non-"to do" status
gets a grey uppercase badge. `DatabaseProfile.inProgressValue` (auto-detected,
regex `in.?progress|doing|wip|…`), mirrored to `Config.inProgressStatusValue`.
Settings editor split status kind / values rows. Installed.
Note: JB's pre-existing "Stablish" profile decoded with the default
"In progress" — he should Re-detect it if his DB names it differently.
Loaded: `features/{task-list,multi-database}.md`, `architecture/models.md`.

### 2026-09-04 (cont.) — JB / claude-code
"How do I make a task in progress?" — click was done-only. Now a click **cycles**
to do → in progress → done (`TaskListModel.statusCycle` / `advance`). `setDone`
→ `setStatus(pageID:value:)` (can also null the field). `TodoTask.originalStatus`
is now `var`. Installed.
Loaded: `features/task-list.md`, `architecture/apis.md`.

### 2026-09-04 (cont.) — JB / claude-code
Reorder-on-click: `ordered()` now tiers to-do (0) → in progress (1) → done (2)
then time, and `advance()` re-sorts (animated) after each click — the row moves
to its group instead of staying put. Reverses the earlier "no reorder on toggle"
call. Installed.
