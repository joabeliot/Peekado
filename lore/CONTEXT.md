# Context

**Focus:** v1 done and in daily use. No active build work — parked until it stops working well.
**Phase:** Alpha (personal daily driver)
**Open:** PKD-1 (distributable for non-devs) — backlog. No tests. No CHANGELOG git hook. `OG.md` + `MISSION.md` unwritten.
**Next:** Nothing scheduled. Revisit when v1 breaks or distribution becomes a goal.

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
