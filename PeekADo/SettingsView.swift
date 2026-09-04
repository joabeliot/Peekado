import SwiftUI

/// The Settings window (a real window — `AppDelegate` hosts it). Manages the
/// database profiles, the shared token, and launch-at-login.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var tokenField = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                databases
                Divider()
                token
                Divider()
                system
            }
            .padding(20)
        }
        .frame(width: 460, height: 480)
        .onAppear { settings.refreshLaunchState() }
    }

    // MARK: - Databases

    private var databases: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Databases").font(.headline)
                Spacer()
                Button {
                    settings.addProfile()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .controlSize(.small)
            }

            Text("The selected one opens when you open Peek-A-Do.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach($settings.profiles) { $profile in
                profileRow($profile)
            }
        }
    }

    private func profileRow(_ profile: Binding<DatabaseProfile>) -> some View {
        let id = profile.wrappedValue.id
        let isPrimary = settings.primaryID == id

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    settings.makePrimary(id)
                } label: {
                    Image(systemName: isPrimary ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isPrimary ? Color.accentColor : .secondary)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .help(isPrimary ? "Primary" : "Make primary")

                TextField("Name", text: profile.name)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))

                Spacer()

                Button {
                    settings.deleteProfile(id)
                } label: {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(settings.profiles.count <= 1)
                .help("Remove")
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 5) {
                gridField("Database ID", profile.databaseID, prompt: "32-hex id from the URL")
                GridRow {
                    Text("Properties").gridColumnAlignment(.trailing)
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        TextField("Name", text: profile.titleProperty).frame(width: 90)
                        TextField("Due", text: profile.dateProperty).frame(width: 90)
                        TextField("Status", text: profile.statusProperty).frame(width: 90)
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                }
            }
            .padding(.leading, 24)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(isPrimary ? 0.06 : 0.03))
        )
    }

    private func gridField(_ label: String, _ text: Binding<String>, prompt: String) -> some View {
        GridRow {
            Text(label).gridColumnAlignment(.trailing)
                .font(.caption).foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
        }
    }

    // MARK: - Token

    private var token: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Integration token").font(.headline)
            Text("From notion.so/my-integrations — share every database above with it. Stored in your Keychain.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                SecureField(settings.hasToken ? "•••••• saved — paste to replace" : "secret_… / ntn_…",
                            text: $tokenField)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    settings.saveToken(tokenField)
                    tokenField = ""
                }
                .disabled(tokenField.trimmingCharacters(in: .whitespaces).isEmpty)
                if settings.hasToken {
                    Button("Remove") { settings.removeToken() }
                }
            }
            Text(settings.hasToken ? "✓ token saved" : "no token yet")
                .font(.caption2)
                .foregroundStyle(settings.hasToken ? Color.green : Color.secondary)
        }
    }

    // MARK: - System

    private var system: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Start at login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)

            if settings.launchNeedsApproval {
                Text("Approve Peek-A-Do in System Settings › General › Login Items.")
                    .font(.caption2).foregroundStyle(.orange)
            }

            Text("Toggle the dropdown anywhere by double-tapping Control. "
                 + "Needs Accessibility permission (System Settings › Privacy & Security).")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
