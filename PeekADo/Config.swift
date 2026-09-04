import Foundation

/// Notion config.
///
/// - The **token** lives in the Keychain (`KeychainStore`), entered in Settings.
/// - The **database id** and **property names** live in `UserDefaults`, also
///   entered in Settings — `AppSettings` writes them, this reads them back.
/// - The values below with no Settings field are plain constants: edit them here
///   if your database differs.
enum Config {

    /// `UserDefaults` keys for the Settings-editable values. `AppSettings` and
    /// `Config` are the only things that touch these.
    enum Key {
        static let databaseID     = "notion.databaseID"
        static let titleProperty  = "notion.titleProperty"
        static let dateProperty   = "notion.dateProperty"
        static let statusProperty = "notion.statusProperty"
        static let statusKind      = "notion.statusKind"
        static let doneValue       = "notion.doneValue"
        static let inProgressValue = "notion.inProgressValue"
        static let newTaskValue    = "notion.newTaskValue"
    }

    // MARK: - Settings-backed (mirrored from the primary DatabaseProfile)

    static var databaseID: String     { value(Key.databaseID,     or: "") }
    static var titleProperty: String  { value(Key.titleProperty,  or: "Name") }
    static var dateProperty: String   { value(Key.dateProperty,   or: "Due") }
    static var statusProperty: String { value(Key.statusProperty, or: "Status") }

    /// Is `statusProperty` a Notion **Status** field or a **Select** field?
    static var statusPropertyKind: StatusKind {
        StatusKind(rawValue: value(Key.statusKind, or: "select")) ?? .select
    }

    /// The `statusProperty` value that means "finished".
    static var doneStatusValue: String { value(Key.doneValue, or: "Done") }

    /// The `statusProperty` value that means "in progress".
    static var inProgressStatusValue: String { value(Key.inProgressValue, or: "In progress") }

    /// Status applied to a task created from the dropdown. `""` ⇒ no status set.
    static var newTaskStatusValue: String {
        UserDefaults.standard.string(forKey: Key.newTaskValue) ?? "To do"
    }

    // MARK: - Fixed constant

    /// Notion's dated API version.
    static let notionAPIVersion = "2022-06-28"

    enum StatusKind: String {
        case status
        case select
    }

    // MARK: -

    private static func value(_ key: String, or fallback: String) -> String {
        let stored = (UserDefaults.standard.string(forKey: key) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stored.isEmpty ? fallback : stored
    }
}
