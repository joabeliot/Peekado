import Foundation
import AppKit
import ServiceManagement

/// App-wide settings: the database profiles, which one is primary, whether a
/// token is saved, and launch-at-login.
///
/// The **primary** profile's values are mirrored into the flat `Config.Key.*`
/// UserDefaults keys, so `Config` (and `NotionClient`, off the main actor) can
/// keep reading them without knowing profiles exist.
@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    @Published var profiles: [DatabaseProfile] { didSet { persist() } }
    @Published var primaryID: UUID? { didSet { persist() } }

    @Published private(set) var hasToken: Bool
    @Published private(set) var launchAtLogin = false
    @Published private(set) var launchNeedsApproval = false

    private let defaults = UserDefaults.standard
    private enum Key {
        static let profiles  = "notion.profiles"
        static let primaryID = "notion.primaryProfileID"
    }

    private init() {
        hasToken = KeychainStore.readToken() != nil

        // Load stored profiles.
        if let data = defaults.data(forKey: Key.profiles),
           let stored = try? JSONDecoder().decode([DatabaseProfile].self, from: data),
           !stored.isEmpty {
            profiles = stored
            primaryID = defaults.string(forKey: Key.primaryID).flatMap(UUID.init(uuidString:))
        } else {
            // First run on this version — migrate the old single flat config, if any.
            let migrated = DatabaseProfile(
                name: "My tasks",
                databaseID: defaults.string(forKey: Config.Key.databaseID) ?? "",
                titleProperty: defaults.string(forKey: Config.Key.titleProperty) ?? "Name",
                dateProperty: defaults.string(forKey: Config.Key.dateProperty) ?? "Due",
                statusProperty: defaults.string(forKey: Config.Key.statusProperty) ?? "Status"
            )
            profiles = [migrated]
            primaryID = migrated.id
        }

        // `didSet` doesn't fire from `init`, so mirror + save once explicitly.
        if primaryID == nil || !profiles.contains(where: { $0.id == primaryID }) {
            primaryID = profiles.first?.id
        }
        persist()
        refreshLaunchState()
    }

    // MARK: - Profiles

    var primaryProfile: DatabaseProfile? {
        profiles.first { $0.id == primaryID } ?? profiles.first
    }

    func addProfile() {
        let new = DatabaseProfile()
        profiles.append(new)
        if primaryID == nil { primaryID = new.id }
    }

    func deleteProfile(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        if primaryID == id { primaryID = profiles.first?.id }
    }

    func makePrimary(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        primaryID = id
    }

    /// JSON-encode the profiles, remember the primary, and mirror the primary's
    /// values into the flat keys `Config` reads.
    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Key.profiles)
        }
        defaults.set(primaryID?.uuidString, forKey: Key.primaryID)

        let p = primaryProfile
        defaults.set(p?.databaseID.trimmed ?? "",     forKey: Config.Key.databaseID)
        defaults.set(p?.titleProperty.trimmed ?? "",  forKey: Config.Key.titleProperty)
        defaults.set(p?.dateProperty.trimmed ?? "",   forKey: Config.Key.dateProperty)
        defaults.set(p?.statusProperty.trimmed ?? "", forKey: Config.Key.statusProperty)
    }

    var isConfigured: Bool { primaryProfile?.isUsable == true }

    // MARK: - Token

    func saveToken(_ raw: String) {
        let token = raw.trimmed
        guard !token.isEmpty else { return }
        KeychainStore.saveToken(token)
        hasToken = true
    }

    func removeToken() {
        KeychainStore.deleteToken()
        hasToken = false
    }

    // MARK: - Launch at login

    func refreshLaunchState() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        launchNeedsApproval = status == .requiresApproval
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSSound.beep()
        }
        refreshLaunchState()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
