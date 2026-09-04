import Foundation

/// Thin, dependency-free wrapper over the two Notion endpoints Peek-a-do needs:
/// query a database, and patch a page.
struct NotionClient {

    enum ClientError: LocalizedError {
        case missingToken
        case missingDatabaseID
        case http(status: Int, body: String)
        case schema(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .missingToken:
                return "No Notion token yet — add it in Settings (the gear icon)."
            case .missingDatabaseID:
                return "No database ID yet — add it in Settings (the gear icon)."
            case let .http(status, body):
                return "Notion returned \(status).\n\(body)"
            case let .schema(message):
                return message
            case .badResponse:
                return "Couldn't make sense of Notion's response."
            }
        }
    }

    private let token: String
    private let session: URLSession

    /// Throws `.missingToken` / `.missingDatabaseID` if setup is incomplete.
    init(session: URLSession = .shared) throws {
        guard !Config.databaseID.isEmpty else {
            throw ClientError.missingDatabaseID
        }
        guard let token = KeychainStore.readToken() else {
            throw ClientError.missingToken
        }
        self.token = token
        self.session = session
    }

    // MARK: - Schema discovery

    /// What a paste-the-id setup fills in.
    struct DatabaseSchema {
        var databaseID: String
        var name: String
        var titleProperty: String
        var dateProperty: String
        var statusProperty: String
        var statusKind: Config.StatusKind
        var doneValue: String
        var newTaskValue: String
    }

    /// Pull the bare database id out of whatever the user pasted — a full URL
    /// (`…/p/<id>?v=<viewid>`, `…/<slug>-<id>?v=…`), a dashed UUID, or the id
    /// itself. Takes the id *before* any `?` so the view id is ignored.
    static func canonicalDatabaseID(_ raw: String) -> String {
        let head = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "?").first.map(String.init) ?? ""
        let lastSegment = head.split(separator: "/").last.map(String.init) ?? head
        // grab a trailing 32-hex run, dashes optional
        if let range = lastSegment.range(
            of: "[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$",
            options: .regularExpression
        ) {
            return lastSegment[range].replacingOccurrences(of: "-", with: "")
        }
        return lastSegment.replacingOccurrences(of: "-", with: "")
    }

    /// `GET /v1/databases/{id}` → guess which property is title / date / status,
    /// the status field's kind, and its "done" / "to do" option names.
    /// Only needs the token (no instance).
    static func fetchDatabaseSchema(id rawID: String) async throws -> DatabaseSchema {
        guard let token = KeychainStore.readToken() else { throw ClientError.missingToken }
        let id = canonicalDatabaseID(rawID)
        guard !id.isEmpty else { throw ClientError.missingDatabaseID }

        var request = URLRequest(url: URL(string: "https://api.notion.com/v1/databases/\(id)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.notionAPIVersion, forHTTPHeaderField: "Notion-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        do {
            try check(response, data)
        } catch ClientError.http(404, _) {
            throw ClientError.schema(
                "Notion couldn't find that database. Check the ID, and make sure the "
                + "database is shared with your Peek-a-Do integration (••• → Connections)."
            )
        }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let props = root["properties"] as? [String: Any]
        else { throw ClientError.badResponse }

        func names(ofType type: String) -> [String] {
            props.compactMap { name, value in
                (value as? [String: Any])?["type"] as? String == type ? name : nil
            }
        }
        func pick(_ candidates: [String], preferring pattern: String) -> String? {
            candidates.first { $0.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
                ?? candidates.first
        }

        guard let title = names(ofType: "title").first else {
            throw ClientError.schema("That database has no title property.")
        }
        guard let date = pick(names(ofType: "date"), preferring: "due|date|when|deadline|scheduled") else {
            throw ClientError.schema("That database has no date property.")
        }

        let kind: Config.StatusKind
        let statusName: String
        if let s = pick(names(ofType: "status"), preferring: "status|state|progress|stage") {
            kind = .status; statusName = s
        } else if let s = pick(names(ofType: "select"), preferring: "status|state|progress|stage") {
            kind = .select; statusName = s
        } else {
            throw ClientError.schema("That database has no status or select property.")
        }

        let options = ((props[statusName] as? [String: Any])?[kind.rawValue] as? [String: Any])?["options"]
            as? [[String: Any]] ?? []
        let optionNames = options.compactMap { $0["name"] as? String }
        let done = optionNames.first {
            $0.range(of: "^(done|complete|completed|finished|closed|shipped|resolved)$",
                     options: [.regularExpression, .caseInsensitive]) != nil
        } ?? "Done"
        let todo = optionNames.first {
            $0.range(of: "^(to.?do|todo|not.?started|backlog|new|open|inbox|next|planned)$",
                     options: [.regularExpression, .caseInsensitive]) != nil
        } ?? optionNames.first ?? "To do"

        let dbName = (root["title"] as? [[String: Any]])?
            .compactMap { $0["plain_text"] as? String }.joined() ?? ""

        return DatabaseSchema(
            databaseID: id,
            name: dbName,
            titleProperty: title,
            dateProperty: date,
            statusProperty: statusName,
            statusKind: kind,
            doneValue: done,
            newTaskValue: todo
        )
    }

    // MARK: - Read

    func fetchTodaysTasks() async throws -> [TodoTask] {
        let url = URL(string: "https://api.notion.com/v1/databases/\(Self.canonicalDatabaseID(Config.databaseID))/query")!
        var request = baseRequest(url: url, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: queryBody())

        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = root["results"] as? [[String: Any]]
        else { throw ClientError.badResponse }

        return results.compactMap(Self.parseTask(from:))
    }

    // MARK: - Write

    /// Creates a task in the database: `title`, `Due` = today, `Status` =
    /// `Config.newTaskStatusValue`. Returns the parsed task Notion hands back.
    func createTask(title: String) async throws -> TodoTask {
        let url = URL(string: "https://api.notion.com/v1/pages")!
        var request = baseRequest(url: url, method: "POST")

        let today = Self.isoDay.string(from: Date())
        var properties: [String: Any] = [
            Config.titleProperty: ["title": [["text": ["content": title]]]],
            Config.dateProperty: ["date": ["start": today]],
        ]
        if !Config.newTaskStatusValue.isEmpty {
            properties[Config.statusProperty] = [
                Config.statusPropertyKind.rawValue: ["name": Config.newTaskStatusValue]
            ]
        }
        let body: [String: Any] = [
            "parent": ["database_id": Self.canonicalDatabaseID(Config.databaseID)],
            "properties": properties,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)

        guard
            let page = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let task = Self.parseTask(from: page)
        else { throw ClientError.badResponse }
        return task
    }

    /// Sets the task's status in Notion.
    /// `done == true` writes `Config.doneStatusValue`; `done == false` writes
    /// `restoreStatus` (whatever the task had before you checked it).
    func setDone(pageID: String, done: Bool, restoreStatus: String) async throws {
        let url = URL(string: "https://api.notion.com/v1/pages/\(pageID)")!
        var request = baseRequest(url: url, method: "PATCH")

        let value = done ? Config.doneStatusValue : restoreStatus
        let kindKey = Config.statusPropertyKind.rawValue  // "status" or "select"
        let body: [String: Any] = [
            "properties": [
                Config.statusProperty: [
                    kindKey: ["name": value]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)
    }

    // MARK: - Request building

    private func baseRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.notionAPIVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func queryBody() -> [String: Any] {
        let today = Self.isoDay.string(from: Date())

        // Everything due today, Done included — the dropdown needs the finished
        // ones to show "X of Y done". Completion is read from the status property.
        return [
            "filter": [
                "property": Config.dateProperty,
                "date": ["equals": today],
            ],
            "page_size": 100,
        ]
    }

    // MARK: - Parsing

    private static func parseTask(from page: [String: Any]) -> TodoTask? {
        guard
            let id = page["id"] as? String,
            let properties = page["properties"] as? [String: Any]
        else { return nil }

        let title = plainText(from: properties[Config.titleProperty]) ?? "(untitled)"
        let status = statusName(from: properties[Config.statusProperty])

        return TodoTask(
            id: id,
            title: title,
            done: status == Config.doneStatusValue,
            originalStatus: status ?? "",
            dueTime: time(from: properties[Config.dateProperty])
        )
    }

    /// Concatenates the `plain_text` runs of a `title` or `rich_text` property.
    private static func plainText(from property: Any?) -> String? {
        guard let property = property as? [String: Any] else { return nil }
        let runs = (property["title"] as? [[String: Any]])
            ?? (property["rich_text"] as? [[String: Any]])
            ?? []
        let text = runs.compactMap { $0["plain_text"] as? String }.joined()
        return text.isEmpty ? nil : text
    }

    /// Reads `.status.name` or `.select.name` off a status/select property.
    private static func statusName(from property: Any?) -> String? {
        guard let property = property as? [String: Any] else { return nil }
        if let status = property["status"] as? [String: Any] {
            return status["name"] as? String
        }
        if let select = property["select"] as? [String: Any] {
            return select["name"] as? String
        }
        return nil
    }

    /// Returns the time component of the date property, but only if the start
    /// value actually carried one (ISO8601 with a `T`).
    private static func time(from property: Any?) -> Date? {
        guard
            let property = property as? [String: Any],
            let date = property["date"] as? [String: Any],
            let start = date["start"] as? String,
            start.contains("T")
        else { return nil }
        return parseISO8601(start)
    }

    // MARK: - Helpers

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.badResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.http(status: http.statusCode, body: String(body.prefix(300)))
        }
    }

    /// Notion sometimes includes fractional seconds, sometimes not — try both.
    private static func parseISO8601(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
