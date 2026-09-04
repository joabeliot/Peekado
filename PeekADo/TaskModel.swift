import Foundation

/// One row in the dropdown.
///
/// Named `TodoTask`, not `Task`, on purpose — `Task` is Swift's concurrency
/// primitive and shadowing it project-wide is a footgun.
struct TodoTask: Identifiable, Equatable {

    /// The Notion **page** id. This is what PATCH requests target.
    let id: String

    var title: String

    /// Optimistic local state — flips the instant you click the checkbox,
    /// before Notion has confirmed anything.
    var done: Bool

    /// The status value this task had when we fetched it (e.g. "In progress").
    /// Used to put the task back if you *uncheck* it in the same session.
    let originalStatus: String

    /// Time-of-day from the date property, if it carried one.
    var dueTime: Date?
}
