import Foundation

/// The Settings-editable Notion config, mirrored into `UserDefaults` so
/// `Config` (and therefore `NotionClient`, off the main actor) can read it.
///
/// One shared instance — this is app-wide config, and `NotionClient` reads the
/// same `UserDefaults` keys regardless of which actor it's on.
@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    @Published var databaseID: String
    @Published var titleProperty: String
    @Published var dateProperty: String
    @Published var statusProperty: String

    private let defaults = UserDefaults.standard

    private init() {
        databaseID     = defaults.string(forKey: Config.Key.databaseID) ?? ""
        titleProperty  = defaults.string(forKey: Config.Key.titleProperty) ?? "Name"
        dateProperty   = defaults.string(forKey: Config.Key.dateProperty) ?? "Due"
        statusProperty = defaults.string(forKey: Config.Key.statusProperty) ?? "Status"
    }

    /// Trim and persist. Call from the Settings "Save" button.
    func save() {
        databaseID     = databaseID.trimmingCharacters(in: .whitespacesAndNewlines)
        titleProperty  = titleProperty.trimmingCharacters(in: .whitespacesAndNewlines)
        dateProperty   = dateProperty.trimmingCharacters(in: .whitespacesAndNewlines)
        statusProperty = statusProperty.trimmingCharacters(in: .whitespacesAndNewlines)

        defaults.set(databaseID,     forKey: Config.Key.databaseID)
        defaults.set(titleProperty,  forKey: Config.Key.titleProperty)
        defaults.set(dateProperty,   forKey: Config.Key.dateProperty)
        defaults.set(statusProperty, forKey: Config.Key.statusProperty)
    }

    var isConfigured: Bool {
        !databaseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
