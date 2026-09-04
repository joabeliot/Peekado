import SwiftUI
import AppKit

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
    @Published private(set) var isAdding = false

    /// Footer summary, e.g. "1 of 3 done". `nil` when there's nothing to count.
    var summary: String? {
        guard case let .loaded(tasks) = phase, !tasks.isEmpty else { return nil }
        return "\(tasks.filter(\.done).count) of \(tasks.count) done"
    }

    private static let tempPrefix = "temp-"

    /// Pulls today's tasks. Called every time the dropdown opens.
    func refresh() {
        guard !Config.databaseID.isEmpty else {
            phase = .failed(NotionClient.ClientError.missingDatabaseID.localizedDescription)
            return
        }
        guard KeychainStore.readToken() != nil else {
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

    /// The click-cycle of status values: to do → in progress → done → (to do).
    /// Empty / duplicate values are dropped; `done` always closes the loop.
    static func statusCycle() -> [String] {
        var cycle: [String] = []
        func add(_ raw: String) {
            let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty,
                  !cycle.contains(where: { $0.caseInsensitiveCompare(v) == .orderedSame })
            else { return }
            cycle.append(v)
        }
        add(Config.newTaskStatusValue)
        add(Config.inProgressStatusValue)
        add(Config.doneStatusValue)
        return cycle.isEmpty ? [Config.doneStatusValue] : cycle
    }

    /// Advance a task one step around `statusCycle()`. Optimistic, rolls back.
    func advance(_ task: TodoTask) {
        guard !task.id.hasPrefix(Self.tempPrefix) else { return }  // not saved yet
        guard case var .loaded(tasks) = phase,
              let index = tasks.firstIndex(where: { $0.id == task.id })
        else { return }

        let cycle = Self.statusCycle()
        let current = tasks[index].originalStatus
        let next: String
        if let i = cycle.firstIndex(where: { $0.caseInsensitiveCompare(current) == .orderedSame }) {
            next = cycle[(i + 1) % cycle.count]
        } else {
            next = Config.doneStatusValue          // unknown status → mark done
        }

        let before = tasks[index]
        tasks[index].originalStatus = next
        tasks[index].done = next.caseInsensitiveCompare(Config.doneStatusValue) == .orderedSame
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .loaded(Self.ordered(tasks))   // regroup to-do / in progress / done
        }

        let pageID = before.id
        Task {
            do {
                let client = try NotionClient()
                try await client.setStatus(pageID: pageID, value: next)
            } catch {
                if case var .loaded(current) = phase,
                   let i = current.firstIndex(where: { $0.id == pageID }) {
                    current[i] = before
                    withAnimation(.easeInOut(duration: 0.2)) {
                        phase = .loaded(Self.ordered(current))
                    }
                }
                NSSound.beep()
            }
        }
    }

    /// Sort tier: to-do (0) → in progress (1) → done (2), then by time.
    private static func rank(_ t: TodoTask) -> Int {
        if t.done { return 2 }
        if !Config.inProgressStatusValue.isEmpty,
           t.originalStatus.caseInsensitiveCompare(Config.inProgressStatusValue) == .orderedSame {
            return 1
        }
        return 0
    }

    static func ordered(_ tasks: [TodoTask]) -> [TodoTask] {
        tasks.sorted { a, b in
            let (ra, rb) = (rank(a), rank(b))
            if ra != rb { return ra < rb }
            return (a.dueTime ?? .distantFuture) < (b.dueTime ?? .distantFuture)
        }
    }

}

// MARK: - View

struct TaskListView: View {
    @StateObject private var model = TaskListModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var newTaskTitle = ""
    @FocusState private var addFieldFocused: Bool

    /// Opens the Settings window — supplied by `AppDelegate`.
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            addField
            Divider()
            content.frame(minHeight: 90)
            Divider()
            footer
        }
        .frame(width: 320)
        .onAppear { model.refresh() }
        .onChange(of: settings.primaryID) { _ in model.refresh() }
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Peek-A-Do").font(.headline)
                if let name = settings.primaryProfile?.name,
                   settings.profiles.count > 1 {
                    Text(name).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
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
                    if !AppSettings.shared.isConfigured {
                        Button("Open Settings", action: onOpenSettings)
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private func taskList(_ tasks: [TodoTask]) -> some View {
        List(tasks) { task in
            let inProgress = isInProgress(task)
            Button {
                model.advance(task)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: task.done ? "checkmark.circle.fill"
                          : inProgress ? "circle.lefthalf.filled"
                          : "circle")
                        .foregroundStyle(task.done ? Color.accentColor
                                         : inProgress ? Color.orange
                                         : Color.secondary)
                    Text(task.title)
                        .strikethrough(task.done)
                        .foregroundStyle(task.done ? Color.secondary : Color.primary)
                    if let label = statusBadge(task) {
                        Text(label)
                            .font(.system(size: 9, weight: .semibold))
                            .textCase(.uppercase)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(
                                (inProgress ? Color.orange : Color.secondary).opacity(0.16)))
                            .foregroundStyle(inProgress ? Color.orange : Color.secondary)
                    }
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
            .help("Click to advance: to do → in progress → done")
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .frame(maxHeight: 320)
    }

    private func isInProgress(_ t: TodoTask) -> Bool {
        !t.done && !Config.inProgressStatusValue.isEmpty
            && t.originalStatus.caseInsensitiveCompare(Config.inProgressStatusValue) == .orderedSame
    }

    /// A short status label for non-done tasks that carry a status other than the
    /// plain "to do" value (in-progress, or anything custom like "Blocked").
    private func statusBadge(_ t: TodoTask) -> String? {
        guard !t.done, !t.originalStatus.isEmpty else { return nil }
        if t.originalStatus.caseInsensitiveCompare(Config.newTaskStatusValue) == .orderedSame { return nil }
        return t.originalStatus
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
