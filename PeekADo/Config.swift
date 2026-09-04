import Foundation

/// Everything needed to point Peek-a-do at *your* Notion database.
///
/// The integration **token is deliberately not in this file** — it lives in the
/// macOS Keychain and you paste it via the app's Settings panel (the gear icon
/// in the dropdown). That keeps the secret out of git.
///
/// >>> YOU MUST EDIT `databaseID` AND THE PROPERTY NAMES BELOW <<<
enum Config {

    // MARK: - Notion database

    /// The database ID — lives in `LocalConfig.swift` so a real id never lands
    /// in git. Edit it there, then `git update-index --skip-worktree
    /// PeekADo/LocalConfig.swift`.
    static let databaseID = LocalConfig.databaseID

    // MARK: - Property names — match these to YOUR database exactly

    /// The `title`-type property holding the task name.
    static let titleProperty = "Name"

    /// The `date`-type property Peek-a-do filters on ("show me today").
    static let dateProperty = "Due"

    /// The property that tracks completion.
    static let statusProperty = "Status"

    /// Is `statusProperty` a Notion **Status** field or a **Select** field?
    /// The two have different JSON shapes, so Peek-a-do has to be told which.
    ///
    /// Note: Notion's API can only *create* Select properties, so if you want
    /// Peek-a-do to add tasks, use a Select here (`.select`).
    static let statusPropertyKind: StatusKind = .select

    /// The value of `statusProperty` that means "finished".
    static let doneStatusValue = "Done"

    /// Status applied to a task you create from the dropdown.
    /// Set to `""` to create tasks with no status at all.
    static let newTaskStatusValue = "To do"

    // MARK: - API

    /// Notion's dated API version. Leave it unless Notion's changelog says otherwise.
    static let notionAPIVersion = "2022-06-28"

    enum StatusKind: String {
        case status  // Notion "Status" property type
        case select  // Notion "Select" property type
    }
}
