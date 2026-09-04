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
                phase = .loaded(
                    tasks.sorted {
                        ($0.dueTime ?? .distantFuture) < ($1.dueTime ?? .distantFuture)
                    }
                )
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
        Task {
            do {
                let client = try NotionClient()
                try await client.setDone(
                    pageID: snapshot.id,
                    done: newDone,
                    restoreStatus: snapshot.originalStatus
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

    func saveToken(_ raw: String) {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        KeychainStore.saveToken(token)
        hasToken = true
        refresh()
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
            settings
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

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notion integration token")
                .font(.callout).bold()
            Text("Create an internal integration at notion.so/my-integrations, "
                 + "share your task database with it, then paste the secret here. "
                 + "It's stored in your Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("secret_…", text: $tokenField)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Save") {
                    model.saveToken(tokenField)
                    tokenField = ""
                    showingSettings = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tokenField.trimmingCharacters(in: .whitespaces).isEmpty)

                if model.hasToken {
                    Button("Remove") { model.removeToken() }
                }
                Spacer()
            }

            Text(model.hasToken ? "✓ A token is saved." : "No token saved yet.")
                .font(.caption2)
                .foregroundStyle(model.hasToken ? Color.green : Color.secondary)

            Divider().padding(.vertical, 2)

            Toggle("Start at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            if model.launchNeedsApproval {
                Text("Approve Peek-A-Do in System Settings › General › Login Items.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
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
