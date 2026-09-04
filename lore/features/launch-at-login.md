# Feature: Start at login

**Status:** Done

## What It Does
A switch in the Settings popover. On → `SMAppService.mainApp.register()`; off →
`unregister()`. The model reads `SMAppService.mainApp.status` on open and after
each toggle to keep the switch truthful. If macOS returns `.requiresApproval`,
the popover shows an orange line telling the user to approve Peek-A-Do in
System Settings › General › Login Items.

## Edge Cases
- Running from `/Applications` for the registration to stick reliably — running
  from DerivedData (⌘R) can register an odd path.
- `register()` throws → beep, and `refreshLaunchState()` re-reads the real status
  so the switch snaps back to truth.

## Assumptions
- App is the login item itself (no separate helper bundle). True for v1.

## Open Questions
- Worth a first-run nudge to move the app to `/Applications`?

## Notes
Files: `TaskListView` (`TaskListModel.refreshLaunchState` / `setLaunchAtLogin`,
the `Toggle` in `settings`). Framework: `ServiceManagement`.
