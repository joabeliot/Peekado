import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Model

@MainActor
final class TaskListModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case loading
        case loaded([TodoTask])
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published var hasToken: Bool = KeychainStore.readToken() != nil
    @Published private(set) var isAdding = false

    /// Footer summary, e.g. "1 of 3 done". `nil` when there's nothing to count.
    var summary: String? {
        guard case let .loaded(tasks) = phase, !tasks.isEmpty else { return nil }
        return "\(tasks.filter(\.done).count) of \(tasks.count) done"
    }

    /// `true` once macOS will launch Peek-A-Do at login.
    @Published private(set) var launchAtLogin = false
    /// `true` when the login item is registered but the user still has to
    /// approve it in System Settings › General › Login Items.
    @Published private(set) var launchNeedsApproval = false

    private static let tempPrefix = "temp-"

    init() {
        refreshLaunchState()
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

    /// Pulls today's tasks. Called every time the dropdown opens.
    func refresh() {
        hasToken = KeychainStore.readToken() != nil

        guard !Config.databaseID.isEmpty else {
            phase = .failed(NotionClient.ClientError.missingDatabaseID.localizedDescription)
            return
        }
        guard hasToken else {
            phase = .failed(NotionClient.ClientError.missingToken.localizedDescription)
            return
        }

        // Only drop to the spinner when there's nothing to show yet — a re-open
        // with an existing list shouldn't flash empty.
        if case .loaded = phase {} else { phase = .loading }

        Task {
            do {
                let client = try NotionClient()
                let tasks = try await client.fetchTodaysTasks()
                phase = .loaded(Self.ordered(tasks))
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    /// Creates a task in Notion (Due = today), showing it in the list right away.
    func addTask(_ rawTitle: String) {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        guard KeychainStore.readToken() != nil else {
            phase = .failed(NotionClient.ClientError.missingToken.localizedDescription)
            return
        }

        // Optimistic row with a placeholder id until Notion confirms.
        let tempID = Self.tempPrefix + UUID().uuidString
        let optimistic = TodoTask(
            id: tempID,
            title: title,
            done: false,
            originalStatus: Config.newTaskStatusValue,
            dueTime: nil
        )
        var current: [TodoTask] = { if case let .loaded(tasks) = phase { return tasks } else { return [] } }()
        current.append(optimistic)
        phase = .loaded(current)

        isAdding = true
        Task {
            defer { isAdding = false }
            do {
                let client = try NotionClient()
                _ = try await client.createTask(title: title)
                refresh()  // replace the temp row with server truth
            } catch {
                if case var .loaded(tasks) = phase {
                    tasks.removeAll { $0.id == tempID }
                    phase = .loaded(tasks)
                }
                NSSound.beep()
            }
        }
    }

    /// Optimistically flips the checkbox, then tells Notion. Rolls back on failure.
    func toggle(_ task: TodoTask) {
        guard !task.id.hasPrefix(Self.tempPrefix) else { return }  // not saved yet
        guard case var .loaded(tasks) = phase,
              let index = tasks.firstIndex(where: { $0.id == task.id })
        else { return }

        let newDone = !tasks[index].done
        tasks[index].done = newDone
        phase = .loaded(tasks)

        let snapshot = tasks[index]
        // If the task was already Done when we fetched it, un-checking has no
        // sensible "previous" value — fall back to the new-task status.
        let restore = (snapshot.originalStatus.isEmpty || snapshot.originalStatus == Config.doneStatusValue)
            ? Config.newTaskStatusValue
            : snapshot.originalStatus
        Task {
            do {
                let client = try NotionClient()
                try await client.setDone(
                    pageID: snapshot.id,
                    done: newDone,
                    restoreStatus: restore
                )
            } catch {
                if case var .loaded(current) = phase,
                   let i = current.firstIndex(where: { $0.id == snapshot.id }) {
                    current[i].done = !newDone
                    phase = .loaded(current)
                }
                NSSound.beep()
            }
        }
    }

    /// Open tasks first (by time), completed tasks last (by time).
    static func ordered(_ tasks: [TodoTask]) -> [TodoTask] {
        tasks.sorted { a, b in
            if a.done != b.done { return !a.done }
            return (a.dueTime ?? .distantFuture) < (b.dueTime ?? .distantFuture)
        }
    }

    func saveToken(_ raw: String) {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        KeychainStore.saveToken(token)
        hasToken = true
    }

    func removeToken() {
        KeychainStore.deleteToken()
        hasToken = false
        phase = .failed(NotionClient.ClientError.missingToken.localizedDescription)
    }
}

// MARK: - View

struct TaskListView: View {
    @StateObject private var model = TaskListModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingSettings = false
    @State private var tokenField = ""
    @State private var newTaskTitle = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if !showingSettings {
                addField
                Divider()
            }
            content.frame(minHeight: 90)
            Divider()
            footer
        }
        .frame(width: 320)
        .onAppear {
            model.refresh()
            model.refreshLaunchState()
        }
    }

    // MARK: Add task

    private var addField: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
            TextField("Add a task for today…", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .focused($addFieldFocused)
                .onSubmit(submitNewTask)
            if model.isAdding {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func submitNewTask() {
        let title = newTaskTitle
        newTaskTitle = ""
        model.addTask(title)
        addFieldFocused = true  // keep focus for rapid entry
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text(showingSettings ? "Settings" : "Peek-A-Do")
                .font(.headline)
            Spacer()
            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: showingSettings ? "xmark" : "gearshape")
            }
            .buttonStyle(.borderless)
            .help(showingSettings ? "Back to tasks" : "Notion settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if showingSettings {
            settingsPanel
        } else {
            switch model.phase {
            case .idle, .loading:
                centered {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading…").foregroundStyle(.secondary)
                    }
                }
            case let .loaded(tasks) where tasks.isEmpty:
                centered {
                    Text("Nothing on deck 🎉").foregroundStyle(.secondary)
                }
            case let .loaded(tasks):
                taskList(tasks)
            case let .failed(message):
                centered {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }

    private func taskList(_ tasks: [TodoTask]) -> some View {
        List(tasks) { task in
            Button {
                model.toggle(task)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.done ? Color.accentColor : Color.secondary)
                    Text(task.title)
                        .strikethrough(task.done)
                        .foregroundStyle(task.done ? Color.secondary : Color.primary)
                    Spacer()
                    if let due = task.dueTime {
                        Text(due, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .frame(maxHeight: 320)
    }

    // MARK: Settings

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // ── Database ──────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notion database").font(.callout).bold()
                    settingField("Database ID", text: $settings.databaseID,
                                 prompt: "32-hex id from the database URL")
                    HStack(spacing: 6) {
                        settingField("Title property", text: $settings.titleProperty, prompt: "Name")
                        settingField("Date property", text: $settings.dateProperty, prompt: "Due")
                    }
                    settingField("Status property", text: $settings.statusProperty, prompt: "Status")
                    Text("Status is read as a \(Config.statusPropertyKind.rawValue) field; "
                         + "\"done\" means \"\(Config.doneStatusValue)\". Change those in Config.swift.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // ── Token ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text("Integration token").font(.callout).bold()
                    Text("From notion.so/my-integrations — share the database with it. Stored in your Keychain.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    SecureField(model.hasToken ? "•••••• saved — paste to replace" : "secret_… / ntn_…",
                                text: $tokenField)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Text(model.hasToken ? "✓ token saved" : "no token yet")
                            .font(.caption2)
                            .foregroundStyle(model.hasToken ? Color.green : Color.secondary)
                        Spacer()
                        if model.hasToken {
                            Button("Remove token") { model.removeToken() }
                                .controlSize(.small)
                        }
                    }
                }

                Divider()

                // ── Launch at login ───────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Start at login", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    if model.launchNeedsApproval {
                        Text("Approve Peek-A-Do in System Settings › General › Login Items.")
                            .font(.caption2).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                HStack {
                    Text("Toggle anywhere: ⌃⌥⌘Space")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("Save") {
                        settings.save()
                        let pasted = tokenField.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !pasted.isEmpty {
                            model.saveToken(pasted)
                            tokenField = ""
                        }
                        model.refresh()
                        showingSettings = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 380)
    }

    private func settingField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button {
                model.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)

            Spacer()

            if let summary = model.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Helpers

    private func centered<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        inner()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
}
