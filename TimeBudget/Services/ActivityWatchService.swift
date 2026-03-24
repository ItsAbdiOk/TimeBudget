import Foundation

// MARK: - Models

struct AWEvent: Identifiable {
    let id: String
    let timestamp: Date
    let duration: TimeInterval      // seconds
    let appName: String
    let windowTitle: String
    var url: String?                 // from aw-watcher-web-chrome

    var durationMinutes: Int { Int(duration / 60) }

    /// Extract the domain from a full URL (e.g., "https://github.com/foo" → "github.com")
    var urlDomain: String? {
        guard let url, let components = URLComponents(string: url) else { return nil }
        return components.host?.replacingOccurrences(of: "www.", with: "")
    }

    /// For browser events, extract the site name — prefers URL domain over title heuristics.
    var siteName: String? {
        // If we have a real URL from the Chrome extension, use its domain
        if let domain = urlDomain {
            return domain
        }

        let browsers = ["Google Chrome", "Safari", "Firefox", "Arc", "Brave Browser", "Microsoft Edge", "Orion"]
        guard browsers.contains(appName) else { return nil }

        // Try "- SiteName - Google Chrome" pattern
        let parts = windowTitle.components(separatedBy: " - ")
        if parts.count >= 3 {
            let candidate = parts[parts.count - 2].trimmingCharacters(in: .whitespaces)
            let browserSuffixes = ["Google Chrome", "Safari", "Firefox", "Arc", "Brave", "Edge", "Orion"]
            if !browserSuffixes.contains(where: { candidate.contains($0) }) && !candidate.isEmpty {
                return candidate
            }
        }

        if parts.count >= 2 {
            for part in parts.reversed() {
                let cleaned = part
                    .replacingOccurrences(of: "Google Chrome", with: "")
                    .replacingOccurrences(of: "– ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty && cleaned.count > 1 {
                    return cleaned
                }
            }
        }

        let cleaned = windowTitle
            .replacingOccurrences(of: " - Google Chrome", with: "")
            .replacingOccurrences(of: " – Google Chrome", with: "")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? nil : String(cleaned.prefix(50))
    }
}

/// A bundled block of consecutive desktop activity
struct AWActivityBlock: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let category: String            // "Deep Work", "Productive", "Neutral", "Distraction"
    let topApp: String              // most-used app in this block
    let topSite: String?            // most-used website (if browser-heavy)
    let events: [AWEvent]
    var aiCategory: String?         // set by Apple Intelligence when it refines the category

    /// The effective category: AI-refined if available, otherwise the original
    var effectiveCategory: String { aiCategory ?? category }

    /// Whether this block was re-categorized by Apple Intelligence
    var isAIRefined: Bool { aiCategory != nil && aiCategory != category }

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

// MARK: - Productivity Classification

enum ProductivityTier: String {
    case productive = "Productive"
    case deepWork = "Deep Work"
    case neutral = "Neutral"
    case distraction = "Distraction"

    var color: String {
        switch self {
        case .deepWork: return "systemGreen"
        case .productive: return "systemTeal"
        case .neutral: return "systemOrange"
        case .distraction: return "systemRed"
        }
    }
}

struct ProductivityClassifier {
    // Apps that are always productive (IDE, terminal, etc.)
    static let deepWorkApps: Set<String> = [
        "Xcode", "Visual Studio Code", "Code", "Terminal", "iTerm2",
        "IntelliJ IDEA", "PyCharm", "WebStorm", "Sublime Text", "Vim",
        "Neovim", "Cursor", "Android Studio", "CLion", "DataGrip",
        "Ghostty", "Warp", "Alacritty", "Kitty",
    ]

    static let productiveApps: Set<String> = [
        "Notion", "Obsidian", "Notes", "Pages", "Numbers", "Keynote",
        "Microsoft Word", "Microsoft Excel", "Microsoft PowerPoint",
        "Figma", "Sketch", "Adobe Photoshop", "Adobe Illustrator",
        "Logic Pro", "Final Cut Pro", "DaVinci Resolve",
        "Simulator", "Instruments", "FileMerge",
        "Preview", "Finder", "Calendar", "Mail", "Reminders",
        "System Settings", "Activity Monitor",
    ]

    static let distractionApps: Set<String> = [
        "Messages", "WhatsApp", "Telegram", "Discord",
    ]

    // Websites that are productive
    static let productiveSites: Set<String> = [
        "GitHub", "Stack Overflow", "GitLab", "Bitbucket",
        "Claude", "ChatGPT", "Perplexity",
        "Notion", "Linear", "Jira", "Asana", "Trello",
        "Google Docs", "Google Sheets", "Google Slides",
        "Figma", "Miro", "Confluence",
        "LeetCode", "HackerRank", "Codewars",
        "MDN Web Docs", "Apple Developer", "Swift.org",
        "Coursera", "Udemy", "edX", "Khan Academy",
        "Google Scholar", "arXiv", "ResearchGate",
        "Wikipedia", "Wolfram",
        "localhost", "127.0.0.1", "192.168",
        "AWS", "Google Cloud", "Azure", "Vercel", "Netlify",
        "Docker Hub", "npm",
    ]

    // Websites that are distracting
    static let distractionSites: Set<String> = [
        "YouTube", "Twitter", "X.com", "Reddit",
        "Instagram", "Facebook", "TikTok", "Snapchat",
        "Netflix", "Twitch", "Disney+", "Hulu",
        "9GAG", "Imgur", "BuzzFeed",
        "Amazon", "eBay", "AliExpress",
    ]

    static func classify(app: String, site: String?) -> ProductivityTier {
        // Check app first
        if deepWorkApps.contains(app) { return .deepWork }
        if distractionApps.contains(app) { return .distraction }

        // For browsers, check the site
        let browsers = Set(["Google Chrome", "Safari", "Firefox", "Arc", "Brave Browser", "Microsoft Edge", "Orion"])
        if browsers.contains(app), let site = site {
            let siteLower = site.lowercased()

            for productive in productiveSites {
                if siteLower.contains(productive.lowercased()) { return .productive }
            }
            for distraction in distractionSites {
                if siteLower.contains(distraction.lowercased()) { return .distraction }
            }
            return .neutral
        }

        // Known productive apps
        if productiveApps.contains(app) { return .productive }

        return .neutral
    }

    /// Score: 0-100 based on time distribution across tiers
    static func productivityScore(events: [AWEvent]) -> Int {
        guard !events.isEmpty else { return 0 }

        var tierDurations: [ProductivityTier: TimeInterval] = [:]
        for event in events {
            let tier = classify(app: event.appName, site: event.siteName)
            tierDurations[tier, default: 0] += event.duration
        }

        let total = tierDurations.values.reduce(0, +)
        guard total > 0 else { return 0 }

        // Weights: deepWork=100, productive=80, neutral=40, distraction=0
        let deepWork = (tierDurations[.deepWork] ?? 0) * 100
        let productive = (tierDurations[.productive] ?? 0) * 80
        let neutral = (tierDurations[.neutral] ?? 0) * 40
        let weighted = deepWork + productive + neutral

        return min(100, Int(weighted / total))
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

    /// Fetch raw events for a date (for detailed analysis)
    func fetchRawEvents(for date: Date) async throws -> [AWEvent] {
        guard isConfigured else { throw ActivityWatchError.notConfigured }
        return try await fetchEvents(for: date)
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

        guard let buckets = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ActivityWatchError.invalidResponse
        }

        let prefix = "aw-watcher-window_"
        guard let windowBucket = buckets.keys.first(where: { $0.hasPrefix(prefix) }) else {
            throw ActivityWatchError.noBucket
        }

        let discoveredHostname = String(windowBucket.dropFirst(prefix.count))
        UserDefaults.standard.set(discoveredHostname, forKey: "activitywatch_hostname")
        return discoveredHostname
    }

    // MARK: - Chrome Web Bucket

    /// Fetch web events from the Chrome extension bucket, enrich matching window events with URLs,
    /// and merge unmatched web events into the stream as standalone entries.
    private func enrichWithWebEvents(_ windowEvents: [AWEvent], from start: Date, to end: Date) async -> [AWEvent] {
        guard let webEvents = try? await fetchWebEventsInRange(from: start, to: end), !webEvents.isEmpty else {
            return windowEvents
        }

        print("[ActivityWatch] Enriching \(windowEvents.count) window events with \(webEvents.count) web events")
        for web in webEvents.prefix(5) {
            print("[ActivityWatch]   Web: \(web.url ?? "nil") @ \(web.timestamp) dur=\(Int(web.duration))s")
        }

        var enriched = windowEvents
        var enrichedCount = 0
        var matchedWebIndices = Set<Int>()
        let browsers = Set(["Google Chrome", "Brave Browser", "Microsoft Edge", "Arc"])

        // Pass 1: Enrich browser window events with matching web URLs
        for i in enriched.indices {
            guard enriched[i].url == nil else { continue }
            guard browsers.contains(enriched[i].appName) else { continue }

            let evtStart = enriched[i].timestamp
            let evtEnd = evtStart.addingTimeInterval(enriched[i].duration)

            for (wi, web) in webEvents.enumerated() {
                let webStart = web.timestamp
                let webEnd = webStart.addingTimeInterval(web.duration)
                let overlapStart = max(evtStart, webStart)
                let overlapEnd = min(evtEnd, webEnd)
                if overlapEnd.timeIntervalSince(overlapStart) >= 1 {
                    enriched[i].url = web.url
                    enrichedCount += 1
                    matchedWebIndices.insert(wi)
                    break
                }
            }
        }

        // Pass 2: Add unmatched web events as standalone entries (>= 30s duration)
        // These represent Chrome activity that the window watcher missed
        // (e.g., screen locked, different user session, or window title didn't match)
        var addedCount = 0
        for (wi, web) in webEvents.enumerated() {
            guard !matchedWebIndices.contains(wi) else { continue }
            guard web.duration >= 30 else { continue }
            enriched.append(web)
            addedCount += 1
        }

        let browserCount = windowEvents.filter { browsers.contains($0.appName) }.count
        print("[ActivityWatch] Enriched \(enrichedCount)/\(browserCount) browser events with URLs, added \(addedCount) standalone web events")
        return enriched
    }

    private func fetchWebEventsInRange(from start: Date, to end: Date) async throws -> [AWEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        // Try both bucket name formats
        let bucketNames = ["aw-watcher-web-chrome", "aw-watcher-web-chrome_\(hostname)"]

        for bucketName in bucketNames {
            let urlStr = "http://\(desktopIP):\(port)/api/0/buckets/\(bucketName)/events?start=\(formatter.string(from: start))&end=\(formatter.string(from: end))&limit=-1"
            guard let url = URL(string: urlStr) else {
                print("[ActivityWatch] Invalid URL for bucket \(bucketName)")
                continue
            }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 5

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[ActivityWatch] Non-HTTP response from \(bucketName)")
                    continue
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("[ActivityWatch] HTTP \(httpResponse.statusCode) from \(bucketName)")
                    continue
                }
                let events = try parseWebEvents(data)
                if !events.isEmpty {
                    print("[ActivityWatch] Fetched \(events.count) Chrome web events from \(bucketName)")
                    return events
                } else {
                    print("[ActivityWatch] No web events in \(bucketName) for this time range")
                }
            } catch {
                print("[ActivityWatch] Failed to fetch \(bucketName): \(error.localizedDescription)")
                continue
            }
        }

        print("[ActivityWatch] No Chrome web events found from any bucket")
        return []
    }

    private func parseWebEvents(_ data: Data) throws -> [AWEvent] {
        guard let events = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        return events.compactMap { event -> AWEvent? in
            guard let id = event["id"] as? Int,
                  let timestampStr = event["timestamp"] as? String,
                  let duration = event["duration"] as? Double,
                  let eventData = event["data"] as? [String: Any] else { return nil }

            guard let timestamp = formatter.date(from: timestampStr) ?? fallbackFormatter.date(from: timestampStr) else { return nil }

            let title = (eventData["title"] as? String) ?? ""
            let url = eventData["url"] as? String

            return AWEvent(
                id: "web-\(id)",
                timestamp: timestamp,
                duration: duration,
                appName: "Google Chrome",
                windowTitle: title,
                url: url
            )
        }
        .sorted { $0.timestamp < $1.timestamp }
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

        var windowEvents = try parseEvents(data)

        // Enrich Chrome window events with URLs and merge standalone web events
        windowEvents = await enrichWithWebEvents(windowEvents, from: start, to: end)

        return windowEvents.sorted { $0.timestamp < $1.timestamp }
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
                windowTitle: title,
                url: nil
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
                let block = makeBlock(events: currentEvents, start: blockStart)
                blocks.append(block)
                currentEvents = [event]
                blockStart = event.timestamp
            } else {
                currentEvents.append(event)
            }
        }

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
        var siteDurations: [String: TimeInterval] = [:]
        for event in events {
            appDurations[event.appName, default: 0] += event.duration
            if let site = event.siteName {
                siteDurations[site, default: 0] += event.duration
            }
        }
        let topApp = appDurations.max(by: { $0.value < $1.value })?.key ?? "Unknown"
        let topSite = siteDurations.max(by: { $0.value < $1.value })?.key

        // Use the productivity classifier for the dominant activity
        let tier = ProductivityClassifier.classify(app: topApp, site: topSite)

        return AWActivityBlock(
            start: start,
            end: end,
            category: tier.rawValue,
            topApp: topApp,
            topSite: topSite,
            events: events
        )
    }
}
