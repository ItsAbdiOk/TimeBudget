import Foundation

// MARK: - Models

struct AWEvent: Identifiable {
    let id: String
    let timestamp: Date
    let duration: TimeInterval      // seconds
    let appName: String
    let windowTitle: String

    var durationMinutes: Int { Int(duration / 60) }
}

/// A bundled block of consecutive desktop activity
struct AWActivityBlock: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let category: String            // "Desk Time" or "Deep Work"
    let topApp: String              // most-used app in this block
    let events: [AWEvent]

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

// MARK: - Errors

enum ActivityWatchError: LocalizedError {
    case notConfigured
    case unreachable
    case invalidResponse
    case noBucket
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Desktop IP not configured"
        case .unreachable: return "ActivityWatch server unreachable"
        case .invalidResponse: return "Invalid response from ActivityWatch"
        case .noBucket: return "No window watcher bucket found"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}

// MARK: - Service

final class ActivityWatchService {
    static let shared = ActivityWatchService()

    // MARK: - Configuration (UserDefaults-backed)

    var desktopIP: String {
        UserDefaults.standard.string(forKey: "activitywatch_ip") ?? ""
    }

    var hostname: String {
        UserDefaults.standard.string(forKey: "activitywatch_hostname") ?? ""
    }

    var isConfigured: Bool {
        !desktopIP.isEmpty && !hostname.isEmpty
    }

    private let port = 5600

    // MARK: - Cache

    private var cachedBlocks: [AWActivityBlock] = []
    private var cachedDate: Date?
    private(set) var lastSyncDate: Date?

    var shouldSync: Bool {
        guard let last = lastSyncDate else { return true }
        return Date().timeIntervalSince(last) > 3600
    }

    // MARK: - URLSession with aggressive timeouts

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5     // 5 second request timeout
        config.timeoutIntervalForResource = 10   // 10 second total timeout
        config.waitsForConnectivity = false       // Don't wait if offline
        return URLSession(configuration: config)
    }()

    // MARK: - Public API

    /// Fetch today's desktop activity blocks
    func fetchTodayBlocks() async throws -> [AWActivityBlock] {
        guard isConfigured else { throw ActivityWatchError.notConfigured }

        let today = Calendar.current.startOfDay(for: Date())
        if let cached = cachedDate, Calendar.current.isDate(cached, inSameDayAs: today), !shouldSync {
            return cachedBlocks
        }

        let blocks = try await fetchBlocks(for: today)
        cachedBlocks = blocks
        cachedDate = today
        lastSyncDate = Date()
        return blocks
    }

    /// Fetch desktop activity for a specific date
    func fetchBlocks(for date: Date) async throws -> [AWActivityBlock] {
        guard isConfigured else { throw ActivityWatchError.notConfigured }

        let events = try await fetchEvents(for: date)

        // Filter out short blips (under 2 minutes)
        let meaningful = events.filter { $0.duration >= 120 }

        // Bundle consecutive events into blocks (gap > 5 minutes = new block)
        return bundleIntoBlocks(meaningful)
    }

    /// Fetch blocks for a date range (for trends / heatmaps)
    func fetchBlocks(from start: Date, to end: Date) async throws -> [AWActivityBlock] {
        guard isConfigured else { throw ActivityWatchError.notConfigured }

        let events = try await fetchEventsInRange(from: start, to: end)
        let meaningful = events.filter { $0.duration >= 120 }
        return bundleIntoBlocks(meaningful)
    }

    /// Test connectivity to the ActivityWatch server
    func testConnection() async throws -> Bool {
        guard !desktopIP.isEmpty else { throw ActivityWatchError.notConfigured }

        let url = URL(string: "http://\(desktopIP):\(port)/api/0/info")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw ActivityWatchError.unreachable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityWatchError.invalidResponse
        }

        return (200...299).contains(httpResponse.statusCode)
    }

    /// Auto-discover the hostname by scanning available buckets on the server.
    /// Finds the `aw-watcher-window_*` bucket and extracts the hostname suffix.
    /// Saves the hostname to UserDefaults on success.
    @discardableResult
    func discoverHostname() async throws -> String {
        guard !desktopIP.isEmpty else { throw ActivityWatchError.notConfigured }

        let url = URL(string: "http://\(desktopIP):\(port)/api/0/buckets")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ActivityWatchError.unreachable
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ActivityWatchError.invalidResponse
        }

        // The response is a dict of bucket_id -> bucket_info
        guard let buckets = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ActivityWatchError.invalidResponse
        }

        // Find the window watcher bucket
        let prefix = "aw-watcher-window_"
        guard let windowBucket = buckets.keys.first(where: { $0.hasPrefix(prefix) }) else {
            throw ActivityWatchError.noBucket
        }

        let discoveredHostname = String(windowBucket.dropFirst(prefix.count))
        UserDefaults.standard.set(discoveredHostname, forKey: "activitywatch_hostname")
        return discoveredHostname
    }

    // MARK: - Private: Fetching

    private var bucketId: String {
        "aw-watcher-window_\(hostname)"
    }

    private func fetchEvents(for date: Date) async throws -> [AWEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return try await fetchEventsInRange(from: start, to: end)
    }

    private func fetchEventsInRange(from start: Date, to end: Date) async throws -> [AWEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)

        let urlStr = "http://\(desktopIP):\(port)/api/0/buckets/\(bucketId)/events?start=\(startStr)&end=\(endStr)&limit=-1"

        guard let url = URL(string: urlStr) else {
            throw ActivityWatchError.notConfigured
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ActivityWatchError.unreachable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityWatchError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw ActivityWatchError.noBucket
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ActivityWatchError.invalidResponse
        }

        return try parseEvents(data)
    }

    // MARK: - Private: Parsing

    private func parseEvents(_ data: Data) throws -> [AWEvent] {
        guard let events = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ActivityWatchError.invalidResponse
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        return events.compactMap { event -> AWEvent? in
            guard let id = event["id"] as? Int,
                  let timestampStr = event["timestamp"] as? String,
                  let duration = event["duration"] as? Double,
                  let eventData = event["data"] as? [String: Any] else {
                return nil
            }

            guard let timestamp = formatter.date(from: timestampStr) ?? fallbackFormatter.date(from: timestampStr) else {
                return nil
            }

            let app = (eventData["app"] as? String) ?? "Unknown"
            let title = (eventData["title"] as? String) ?? ""

            return AWEvent(
                id: "\(id)",
                timestamp: timestamp,
                duration: duration,
                appName: app,
                windowTitle: title
            )
        }
        .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Private: Bundling

    /// Bundle consecutive events into activity blocks.
    /// A gap of more than 5 minutes between events starts a new block.
    private func bundleIntoBlocks(_ events: [AWEvent]) -> [AWActivityBlock] {
        guard !events.isEmpty else { return [] }

        let maxGap: TimeInterval = 5 * 60  // 5 minutes
        var blocks: [AWActivityBlock] = []
        var currentEvents: [AWEvent] = [events[0]]
        var blockStart = events[0].timestamp

        for event in events.dropFirst() {
            let prevEnd = currentEvents.last!.timestamp.addingTimeInterval(currentEvents.last!.duration)
            let gap = event.timestamp.timeIntervalSince(prevEnd)

            if gap > maxGap {
                // Finalize current block
                let block = makeBlock(events: currentEvents, start: blockStart)
                blocks.append(block)
                currentEvents = [event]
                blockStart = event.timestamp
            } else {
                currentEvents.append(event)
            }
        }

        // Finalize last block
        if !currentEvents.isEmpty {
            let block = makeBlock(events: currentEvents, start: blockStart)
            blocks.append(block)
        }

        return blocks
    }

    private func makeBlock(events: [AWEvent], start: Date) -> AWActivityBlock {
        let lastEvent = events.last!
        let end = lastEvent.timestamp.addingTimeInterval(lastEvent.duration)

        // Find the most-used app by total duration
        var appDurations: [String: TimeInterval] = [:]
        for event in events {
            appDurations[event.appName, default: 0] += event.duration
        }
        let topApp = appDurations.max(by: { $0.value < $1.value })?.key ?? "Unknown"

        // Categorize: if the top app is a code editor or terminal, it's "Deep Work"
        let deepWorkApps = Set([
            "Xcode", "Visual Studio Code", "Code", "Terminal", "iTerm2",
            "IntelliJ IDEA", "PyCharm", "WebStorm", "Sublime Text", "Vim",
            "Neovim", "Cursor", "Android Studio", "CLion", "DataGrip",
        ])
        let category = deepWorkApps.contains(topApp) ? "Deep Work" : "Desk Time"

        return AWActivityBlock(
            start: start,
            end: end,
            category: category,
            topApp: topApp,
            events: events
        )
    }
}
