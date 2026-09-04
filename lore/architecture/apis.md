# Architecture — APIs

## Notion API (the only external service)

- **Base:** `https://api.notion.com/v1`
- **Auth:** `Authorization: Bearer <internal integration token>` — from Keychain.
- **Version header:** `Notion-Version: 2022-06-28` (`Config.notionAPIVersion`).
- **Content-Type:** `application/json` on every request.
- All calls go through `NotionClient`. `init()` throws `.missingToken` if the
  Keychain has none.

### `fetchTodaysTasks()` → `POST /databases/{databaseID}/query`
Body:
```json
{
  "filter": { "and": [
    { "property": "<dateProperty>",   "date":   { "equals": "<yyyy-MM-dd>" } },
    { "property": "<statusProperty>", "<status|select>": { "does_not_equal": "<doneStatusValue>" } }
  ]},
  "page_size": 100
}
```
`does_not_equal` also matches rows where the property is empty. No pagination
handling — 100-task ceiling per day is fine.

### `setDone(pageID:done:restoreStatus:)` → `PATCH /pages/{pageID}`
```json
{ "properties": { "<statusProperty>": { "<status|select>": { "name": "<value>" } } } }
```
`value` = `doneStatusValue` when checking, `restoreStatus` when un-checking.

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
- **ServiceManagement**: `SMAppService.mainApp` for the login item. `.status`
  can be `.enabled`, `.requiresApproval` (needs System Settings › Login Items),
  `.notRegistered`.
