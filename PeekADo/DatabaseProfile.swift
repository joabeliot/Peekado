import Foundation

/// One Notion database Peek-A-Do can show. The **primary** one opens by default;
/// swap primary anytime in the Settings window.
///
/// All profiles share the single integration token — they're expected to live in
/// the same workspace / be shared with the same integration.
///
/// Paste a database id and let `NotionClient.fetchDatabaseSchema` fill the rest;
/// the fields are still editable if the guesses are wrong.
struct DatabaseProfile: Codable, Identifiable, Equatable {

    var id: UUID
    var name: String

    /// 32-hex id from the database URL (`notion.so/<workspace>/<THIS>?v=…`).
    var databaseID: String

    var titleProperty: String
    var dateProperty: String
    var statusProperty: String

    /// "status" or "select" — the Notion type of `statusProperty`.
    var statusKind: String
    /// The `statusProperty` value that means "finished".
    var doneValue: String
    /// Status applied to a task created from the dropdown. `""` ⇒ no status set.
    var newTaskValue: String

    init(
        id: UUID = UUID(),
        name: String = "New database",
        databaseID: String = "",
        titleProperty: String = "Name",
        dateProperty: String = "Due",
        statusProperty: String = "Status",
        statusKind: String = "select",
        doneValue: String = "Done",
        newTaskValue: String = "To do"
    ) {
        self.id = id
        self.name = name
        self.databaseID = databaseID
        self.titleProperty = titleProperty
        self.dateProperty = dateProperty
        self.statusProperty = statusProperty
        self.statusKind = statusKind
        self.doneValue = doneValue
        self.newTaskValue = newTaskValue
    }

    /// Lenient decode so profiles written by older builds (no status fields)
    /// still load, with sensible fallbacks.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Database"
        databaseID = try c.decodeIfPresent(String.self, forKey: .databaseID) ?? ""
        titleProperty = try c.decodeIfPresent(String.self, forKey: .titleProperty) ?? "Name"
        dateProperty = try c.decodeIfPresent(String.self, forKey: .dateProperty) ?? "Due"
        statusProperty = try c.decodeIfPresent(String.self, forKey: .statusProperty) ?? "Status"
        statusKind = try c.decodeIfPresent(String.self, forKey: .statusKind) ?? "select"
        doneValue = try c.decodeIfPresent(String.self, forKey: .doneValue) ?? "Done"
        newTaskValue = try c.decodeIfPresent(String.self, forKey: .newTaskValue) ?? "To do"
    }

    var isUsable: Bool {
        !databaseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
