import Foundation

/// One Notion database Peek-A-Do can show. The **primary** one opens by default;
/// swap primary anytime in the Settings window.
///
/// All profiles share the single integration token — they're expected to live in
/// the same workspace / be shared with the same integration.
struct DatabaseProfile: Codable, Identifiable, Equatable {

    var id: UUID
    var name: String

    /// 32-hex id from the database URL (`notion.so/<workspace>/<THIS>?v=…`).
    var databaseID: String

    var titleProperty: String
    var dateProperty: String
    var statusProperty: String

    init(
        id: UUID = UUID(),
        name: String = "New database",
        databaseID: String = "",
        titleProperty: String = "Name",
        dateProperty: String = "Due",
        statusProperty: String = "Status"
    ) {
        self.id = id
        self.name = name
        self.databaseID = databaseID
        self.titleProperty = titleProperty
        self.dateProperty = dateProperty
        self.statusProperty = statusProperty
    }

    var isUsable: Bool {
        !databaseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
