# Context

**Focus:** v1 shipped and running standalone. Stabilising + deciding what's next.
**Phase:** Alpha
**Open:** No tests yet. No CHANGELOG git hook installed. `lore/OG.md` + `MISSION.md` unwritten.
**Next:** Decide v2 scope (background refresh? "this week" view? multi-status filter?). Add a smoke test around Notion JSON parsing.

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
