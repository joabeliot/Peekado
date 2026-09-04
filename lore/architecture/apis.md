# Architecture — APIs

## Notion API (the only external service)

- **Base:** `https://api.notion.com/v1`
- **Auth:** `Authorization: Bearer <internal integration token>` — from Keychain.
- **Version header:** `Notion-Version: 2022-06-28` (`Config.notionAPIVersion`).
- **Content-Type:** `application/json` on every request.
- All calls go through `NotionClient`. `init()` throws `.missingDatabaseID` if
  `Config.databaseID` (a UserDefaults value set in Settings) is empty, then
  `.missingToken` if the Keychain has none.
- `Config.databaseID` / `titleProperty` / `dateProperty` / `statusProperty` are
  read from UserDefaults (set in the Settings panel via `AppSettings`).

### `fetchDatabaseSchema(id:)` → `GET /databases/{id}` (static)
Reads `properties` (a `{name: {type, …}}` map) + the db `title`. Picks the
title/date/status property by `type`, the status kind from that type, and
done/to-do option names by regex over the option list. Throws `.schema(String)`
when a required property type is missing. Only needs the token (no instance).

### `fetchTodaysTasks()` → `POST /databases/{databaseID}/query`
Body:
```json
{
  "filter": { "property": "<dateProperty>", "date": { "equals": "<yyyy-MM-dd>" } },
  "page_size": 100
}
```
Filters on date only — Done tasks are fetched too, so the footer can show
"X of Y done". No pagination handling — 100-task ceiling per day is fine.
See `decisions/show-done-tasks.md`.

### `setStatus(pageID:value:)` → `PATCH /pages/{pageID}`
```json
{ "properties": { "<statusProperty>": { "<status|select>": { "name": "<value>" } } } }
```
`value` = the next step from `TaskListModel.statusCycle()`. Empty `value` sends
`null` for the field, clearing the status.

### `createTask(title:)` → `POST /pages`
```json
{
  "parent": { "database_id": "<databaseID>" },
  "properties": {
    "<titleProperty>": { "title": [ { "text": { "content": "<title>" } } ] },
    "<dateProperty>":  { "date": { "start": "<yyyy-MM-dd today>" } },
    "<statusProperty>": { "<status|select>": { "name": "<newTaskStatusValue>" } }
  }
}
```
Status key omitted when `newTaskStatusValue == ""`.

## Gotchas
- The integration must be added to the database in Notion (••• → Connections),
  or every call 404s the database.
- The Notion API **cannot create a true Status property** — only Select. Hence
  `statusPropertyKind` and the guidance to use `.select`.
- Non-2xx → `ClientError.http(status, body)` with the first 300 chars of the
  response body, surfaced in the dropdown's error state.

## System APIs
- **Keychain** (`Security`): one generic-password item, service `app.arque.peekado`,
  account `notion-integration-token`, accessible `AfterFirstUnlock`.
- **UserDefaults**: `notion.profiles` (JSON `[DatabaseProfile]`, authoritative) +
  `notion.primaryProfileID`. `AppSettings.persist()` mirrors the primary into the
  flat `Config.Key.*` keys (`notion.databaseID`, `notion.titleProperty`,
  `notion.dateProperty`, `notion.statusProperty`) which `Config` reads.
- **ServiceManagement**: `SMAppService.mainApp` for the login item. `.status`
  can be `.enabled`, `.requiresApproval` (needs System Settings › Login Items),
  `.notRegistered`.
- **Global NSEvent monitor** (`DoubleTapMonitor`): `.flagsChanged` for the
  double-tap-Control toggle. Needs Accessibility permission (`AXIsProcessTrusted`
  prompt in `AppDelegate`); no entitlement.
