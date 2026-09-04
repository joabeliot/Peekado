import SwiftUI

/// The Settings window (a real window — `AppDelegate` hosts it). Manages the
/// database profiles, the shared token, and launch-at-login.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var tokenField = ""

    @State private var newDBID = ""
    @State private var busyRows: Set<UUID> = []
    @State private var rowErrors: [UUID: String] = [:]
    @State private var expandedRows: Set<UUID> = []

    var body: some View {
        TabView {
            tab { databases }
                .tabItem { Label("Databases", systemImage: "tablecells") }
            tab { token }
                .tabItem { Label("Notion", systemImage: "key.horizontal") }
            tab { system }
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 480, height: 540)
        .onAppear { settings.refreshLaunchState() }
    }

    private func tab<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
    }

    // MARK: - Databases

    private var databases: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Databases").font(.headline)
            Text("Paste a database ID — Peek-A-Do reads the rest from Notion. "
                 + "The selected radio button is the one that opens.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                TextField("Paste a new database ID…", text: $newDBID)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addNew)
                Button("Add & set up", action: addNew)
                    .disabled(newDBID.trimmingCharacters(in: .whitespaces).isEmpty || !settings.hasToken)
            }
            if !settings.hasToken {
                Text("Save your integration token in the Notion tab first.")
                    .font(.caption2).foregroundStyle(.orange)
            }

            ForEach($settings.profiles) { $profile in
                profileRow($profile)
            }
        }
    }

    private func profileRow(_ profile: Binding<DatabaseProfile>) -> some View {
        let id = profile.wrappedValue.id
        let isPrimary = settings.primaryID == id
        let p = profile.wrappedValue

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

                if busyRows.contains(id) { ProgressView().controlSize(.small) }

                Spacer()

                Button {
                    settings.deleteProfile(id)
                    rowErrors[id] = nil; expandedRows.remove(id)
                } label: {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(settings.profiles.count <= 1)
                .help("Remove")
            }

            HStack(spacing: 6) {
                Group {
                    if let err = rowErrors[id] {
                        Text(err).foregroundStyle(.red)
                    } else if !p.isUsable {
                        Text("not set up — paste an ID in Edit").foregroundStyle(.orange)
                    } else {
                        Text("\(p.titleProperty) · \(p.dateProperty) · \(p.statusProperty) (\(p.statusKind)), done → \(p.doneValue)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption2)
                .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button("Re-detect") { detect(id) }
                    .controlSize(.mini)
                    .disabled(busyRows.contains(id) || !p.isUsable || !settings.hasToken)
                Button(expandedRows.contains(id) ? "Hide" : "Edit") {
                    if expandedRows.contains(id) { expandedRows.remove(id) } else { expandedRows.insert(id) }
                }
                .controlSize(.mini)
            }
            .padding(.leading, 24)

            if expandedRows.contains(id) {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 5) {
                    gridField("Database ID", profile.databaseID, prompt: "32-hex id from the URL")
                    GridRow {
                        Text("Properties").gridColumnAlignment(.trailing)
                            .font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            TextField("Name", text: profile.titleProperty).frame(width: 84)
                            TextField("Due", text: profile.dateProperty).frame(width: 84)
                            TextField("Status", text: profile.statusProperty).frame(width: 84)
                        }
                        .textFieldStyle(.roundedBorder).font(.callout)
                    }
                    GridRow {
                        Text("Status").gridColumnAlignment(.trailing)
                            .font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Picker("", selection: profile.statusKind) {
                                Text("Select").tag("select")
                                Text("Status").tag("status")
                            }
                            .labelsHidden().frame(width: 90)
                            TextField("done", text: profile.doneValue).frame(width: 84)
                            TextField("to do", text: profile.newTaskValue).frame(width: 84)
                        }
                        .textFieldStyle(.roundedBorder).font(.callout)
                    }
                }
                .padding(.leading, 24)
            }
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

    // MARK: - Actions

    private func addNew() {
        let raw = newDBID.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty, settings.hasToken else { return }
        newDBID = ""
        let id = settings.addProfile(databaseID: raw)
        detect(id)
    }

    private func detect(_ id: UUID) {
        busyRows.insert(id); rowErrors[id] = nil
        Task {
            let err = await settings.detectSchema(for: id)
            busyRows.remove(id)
            if let err {
                rowErrors[id] = err
                expandedRows.insert(id)   // open the fields so it can be fixed
            }
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
