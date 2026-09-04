# Test Registry

## Covered
_Nothing automated yet._ v1 was verified manually against a live Notion
workspace: fetch, toggle (both directions), add, empty state, missing-token
state, launch-at-login toggle.

## Not Covered
- Notion JSON → `TodoTask` parsing (title fallback, status vs select, date-only
  vs datetime, malformed rows dropped)
- Query-body construction (today string, status/select key switch)
- Optimistic toggle + rollback on HTTP error
- Optimistic add + temp-row replacement / removal on error
- `KeychainStore` round-trip
- `ClientError` message formatting

## Known Gaps
- No test target in the Xcode project yet. Adding one means extending the
  hand-written pbxproj (or regenerating via Xcode).
- `NotionClient` uses `URLSession.shared` by default but takes an injectable
  `session` — a `URLProtocol` stub is the intended path for network tests.
