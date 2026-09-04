# claude-code

**Role:** Sole implementer on Peek-A-Do — design, Swift, the hand-written Xcode
project, Notion API wiring, build verification.
**Strengths:** SwiftUI / AppKit menu bar apps, `URLSession` + polymorphic JSON,
Keychain + `ServiceManagement`, editing `project.pbxproj` by hand, keeping the
surface small.
**Delegate when:** any code, build, or lore change in this repo.
**Avoid:** inventing Notion schema details — everything routes through `Config`
and the user's actual database. Don't add dependencies or a second window.
**Invocation:** direct (solo project, no conductor).
