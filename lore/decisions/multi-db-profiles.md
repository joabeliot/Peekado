# Multiple DB profiles, mirrored into the flat config keys

**Date:** 2026-09-04
**Status:** Decided (extends `features/settings-config.md`)

## Decided
Config is a list of `DatabaseProfile` values + a `primaryID`, stored as JSON in
UserDefaults (`notion.profiles`, `notion.primaryProfileID`). The **primary**
profile's fields are copied into the existing flat keys (`notion.databaseID`,
`notion.titleProperty`, …) on every change. `Config` and `NotionClient` are
unchanged — they read the flat keys as before.

## Why
- The read path (`Config`) is used by `NotionClient` off the main actor.
  Re-plumbing it to resolve "the primary profile" would drag `@MainActor`
  `AppSettings` into non-isolated code. Mirroring keeps that boundary clean and
  the diff tiny — `Config.swift` and `NotionClient.swift` didn't change at all.
- The flat keys are also the natural migration target from the previous
  single-database version.

## Rejected
- **`NotionClient` reads `AppSettings.primaryProfile` directly** — actor
  boundary; would need a snapshot passed through every call site.
- **A profile struct with its own token per DB** — JB confirmed one shared
  token; skip the complexity until a real multi-workspace need shows up.

## Update 2026-09-04
`statusKind` / `doneValue` / `newTaskValue` moved into `DatabaseProfile` after
all (mirrored to new flat keys) — needed once "paste an id and auto-detect the
schema" landed, since detection knows the real type + option names per DB.
Only `notionAPIVersion` is still a hard-coded `Config` constant.

## Consequences
- Two representations of the primary DB (the profile, and the mirrored flat
  keys). `AppSettings.persist()` is the single writer of the mirror — nothing
  else should touch `Config.Key.*`.
- Migration path (flat → one profile) runs once; after that `notion.profiles` is
  authoritative and the flat keys are a derived cache.
