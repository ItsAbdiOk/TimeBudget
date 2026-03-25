import Foundation

// MARK: - Device Source

enum AWSourceDevice: String, Codable {
    case mac
    case iphone
    case unknown
}

// MARK: - Models

struct AWEvent: Identifiable {
    let id: String
    let timestamp: Date
    let duration: TimeInterval      // seconds
    let appName: String
    let windowTitle: String
    var url: String?                 // from aw-watcher-web-chrome
    var sourceDevice: AWSourceDevice = .unknown

    var durationMinutes: Int { Int(duration / 60) }

    /// Extract the domain from a full URL (e.g., "https://github.com/foo" → "github.com")
    var urlDomain: String? {
        guard let url, let components = URLComponents(string: url) else { return nil }
        return components.host?.replacingOccurrences(of: "www.", with: "")
    }

    /// Site name: real URL domain preferred, then known-site matching from window titles.
    var siteName: String? {
        // Best: real URL from Chrome extension
        if let domain = urlDomain { return domain }

        // Fallback: match known sites from browser window titles
        let browsers: Set<String> = ["Google Chrome", "Safari", "Firefox", "Arc", "Brave Browser", "Microsoft Edge", "Orion"]
        guard browsers.contains(appName) else { return nil }

        let titleLower = windowTitle.lowercased()

        // Map of title keywords → clean domain names
        // Only match known sites to avoid garbage like "1.2 GB" or profile names
        let knownSites: [(keywords: [String], domain: String)] = [
            // Dev / Deep Work
            (["github.com", "github"], "github.com"),
            (["gitlab"], "gitlab.com"),
            (["stack overflow", "stackoverflow"], "stackoverflow.com"),
            (["claude.ai", "claude"], "claude.ai"),
            (["chatgpt"], "chatgpt.com"),
            (["perplexity"], "perplexity.ai"),
            (["notion.so", "notion"], "notion.so"),
            (["linear"], "linear.app"),
            (["figma"], "figma.com"),
            (["vercel"], "vercel.com"),
            (["netlify"], "netlify.com"),
            (["localhost", "127.0.0.1"], "localhost"),
            (["developer.apple"], "developer.apple.com"),
            (["swift.org"], "swift.org"),
            // Docs / Productive
            (["docs.google"], "docs.google.com"),
            (["sheets.google"], "sheets.google.com"),
            (["slides.google"], "slides.google.com"),
            (["drive.google"], "drive.google.com"),
            (["wikipedia"], "wikipedia.org"),
            (["medium.com"], "medium.com"),
            (["coursera"], "coursera.org"),
            (["udemy"], "udemy.com"),
            // Distraction
            (["youtube.com", "youtube"], "youtube.com"),
            (["twitter.com", "x.com"], "x.com"),
            (["reddit.com", "reddit"], "reddit.com"),
            (["instagram"], "instagram.com"),
            (["facebook"], "facebook.com"),
            (["tiktok"], "tiktok.com"),
            (["netflix"], "netflix.com"),
            (["twitch.tv", "twitch"], "twitch.tv"),
            (["discord.com"], "discord.com"),
            (["amazon"], "amazon.com"),
            // Communication
            (["gmail"], "gmail.com"),
            (["outlook"], "outlook.com"),
            (["slack"], "slack.com"),
            (["zoom"], "zoom.us"),
            (["meet.google"], "meet.google.com"),
            (["teams.microsoft"], "teams.microsoft.com"),
        ]

        for site in knownSites {
            for keyword in site.keywords {
                if titleLower.contains(keyword) {
                    return site.domain
                }
            }
        }

        return nil
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

    /// The dominant device in this block (most events from which device)
    var dominantDevice: AWSourceDevice {
        var counts: [AWSourceDevice: TimeInterval] = [:]
        for event in events {
            counts[event.sourceDevice, default: 0] += event.duration
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? .mac
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
        "Claude",
    ]

    static let productiveApps: Set<String> = [
        "Notion", "Obsidian", "Notes", "Pages", "Numbers", "Keynote",
        "Microsoft Word", "Microsoft Excel", "Microsoft PowerPoint",
        "Figma", "Sketch", "Adobe Photoshop", "Adobe Illustrator",
        "Logic Pro", "Final Cut Pro", "DaVinci Resolve",
        "Simulator", "Instruments", "FileMerge",
        "Preview", "Finder", "Calendar", "Mail", "Reminders",
        "System Settings", "Activity Monitor",
        // iOS apps (resolved display names from bundle IDs)
        "Gmail", "Google Maps", "Slack", "Teams", "Zoom",
        "Photos", "Weather", "Maps", "Health", "Books",
        "Podcasts", "Music", "LinkedIn",
    ]

    static let distractionApps: Set<String> = [
        "Messages", "WhatsApp", "Telegram", "Discord",
        "Instagram", "TikTok", "Snapchat", "Facebook",
        "YouTube", "Netflix", "Twitch", "Reddit",
    ]

    // Websites that are productive (matches against domain substrings)
    static let productiveSites: Set<String> = [
        "github", "stackoverflow", "gitlab", "bitbucket",
        "claude", "chatgpt", "perplexity",
        "notion", "linear", "jira", "asana", "trello",
        "docs.google", "sheets.google", "slides.google",
        "figma", "miro", "confluence",
        "leetcode", "hackerrank", "codewars",
        "developer.mozilla", "developer.apple", "swift.org",
        "coursera", "udemy", "edx", "khanacademy",
        "scholar.google", "arxiv", "researchgate",
        "wikipedia", "wolfram",
        "localhost", "127.0.0.1", "192.168",
        "aws.amazon", "cloud.google", "azure", "vercel", "netlify",
        "hub.docker", "npmjs",
    ]

    // Websites that are distracting (matches against domain substrings)
    static let distractionSites: Set<String> = [
        "youtube", "twitter", "x.com", "reddit",
        "instagram", "facebook", "tiktok", "snapchat",
        "netflix", "twitch", "disneyplus", "hulu",
        "9gag", "imgur", "buzzfeed",
        "amazon", "ebay", "aliexpress",
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

    /// System apps that represent the Mac being locked/asleep — not real desk time.
    private static let systemIgnoreList: Set<String> = [
        "loginwindow", "WindowServer", "ScreenSaverEngine",
        "MacUserGenerator", "UserNotificationCenter", "Spotlight", "SecurityAgent",
    ]

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

    // MARK: - Discovered Buckets

    struct DiscoveredBuckets {
        var windowBucket: String?
        var webChromeBuckets: [String] = []
        var screenTimeBuckets: [String] = []
        var hostname: String?
    }

    private(set) var discoveredBuckets: DiscoveredBuckets?

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

    // MARK: - Bucket Discovery Cache

    /// Ensure buckets are discovered at least once per app session.
    /// Re-discovers if not yet done or if it's been over an hour.
    private var lastBucketDiscovery: Date?

    private func ensureBucketsDiscovered() async {
        // Skip if discovered recently (within 1 hour)
        if let last = lastBucketDiscovery, Date().timeIntervalSince(last) < 3600,
           discoveredBuckets != nil {
            return
        }

        do {
            try await discoverHostname()
            lastBucketDiscovery = Date()
        } catch {
            print("[ActivityWatch] Bucket re-discovery failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// Fetch today's desktop activity blocks
    func fetchTodayBlocks() async throws -> [AWActivityBlock] {
        guard isConfigured else { throw ActivityWatchError.notConfigured }
        await ensureBucketsDiscovered()

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
        await ensureBucketsDiscovered()

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

    /// Auto-discover the hostname and all available buckets on the server.
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

        // Discover all bucket types
        var discovered = DiscoveredBuckets()

        for key in buckets.keys {
            if key.hasPrefix("aw-watcher-window_") {
                discovered.windowBucket = key
                discovered.hostname = String(key.dropFirst("aw-watcher-window_".count))
            } else if key.hasPrefix("aw-watcher-web-chrome") {
                discovered.webChromeBuckets.append(key)
            } else if key.hasPrefix("aw-import-screentime") {
                discovered.screenTimeBuckets.append(key)
                print("[ActivityWatch] Found screen time bucket: \(key)")
            }
        }

        guard let windowBucket = discovered.windowBucket,
              let discoveredHostname = discovered.hostname else {
            throw ActivityWatchError.noBucket
        }

        self.discoveredBuckets = discovered
        UserDefaults.standard.set(discoveredHostname, forKey: "activitywatch_hostname")

        print("[ActivityWatch] Discovered buckets — window: \(windowBucket), chrome: \(discovered.webChromeBuckets), screenTime: \(discovered.screenTimeBuckets)")
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

        // Pass 1: Enrich Mac browser window events with matching web URLs
        for i in enriched.indices {
            guard enriched[i].url == nil else { continue }
            guard enriched[i].sourceDevice != .iphone else { continue }
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
                url: url,
                sourceDevice: .mac
            )
        }
        .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Screen Time Bucket (aw-import-screentime)

    /// Common iOS bundle ID → display name mapping
    private static let iosAppNames: [String: String] = [
        "com.apple.MobileSafari": "Safari",
        "com.apple.mobilenotes": "Notes",
        "com.apple.mobilemail": "Mail",
        "com.apple.mobilecal": "Calendar",
        "com.apple.reminders": "Reminders",
        "com.apple.mobileslideshow": "Photos",
        "com.apple.weather": "Weather",
        "com.apple.Maps": "Maps",
        "com.apple.Health": "Health",
        "com.apple.Music": "Music",
        "com.apple.Podcasts": "Podcasts",
        "com.apple.news": "News",
        "com.apple.AppStore": "App Store",
        "com.apple.iBooks": "Books",
        "com.apple.mobiletimer": "Clock",
        "com.apple.calculator": "Calculator",
        "com.apple.camera": "Camera",
        "com.apple.facetime": "FaceTime",
        "com.apple.MobileStore": "Apple Store",
        "com.apple.Preferences": "Settings",
        "com.burbn.instagram": "Instagram",
        "com.google.chrome.ios": "Chrome",
        "com.atebits.Tweetie2": "Twitter",
        "com.zhiliaoapp.musically": "TikTok",
        "com.facebook.Facebook": "Facebook",
        "com.toyopagroup.picaboo": "Snapchat",
        "com.google.ios.youtube": "YouTube",
        "net.whatsapp.WhatsApp": "WhatsApp",
        "com.spotify.client": "Spotify",
        "org.telegram.Telegram": "Telegram",
        "com.reddit.Reddit": "Reddit",
        "com.linkedin.LinkedIn": "LinkedIn",
        "com.discord.Discord": "Discord",
        "com.netflix.Netflix": "Netflix",
        "com.amazon.Amazon": "Amazon",
        "com.google.Gmail": "Gmail",
        "com.google.Maps": "Google Maps",
        "com.slack.Slack": "Slack",
        "com.microsoft.teams": "Teams",
        "us.zoom.videomeetings": "Zoom",
    ]

    /// Resolve an iOS bundle ID or app name to a clean display name.
    private static func resolveAppName(_ raw: String) -> String {
        if let mapped = iosAppNames[raw] { return mapped }
        // If it looks like a bundle ID (contains dots), use last component
        if raw.contains(".") {
            return raw.components(separatedBy: ".").last?.capitalized ?? raw
        }
        return raw
    }

    private func fetchScreenTimeEvents(from start: Date, to end: Date) async -> [AWEvent] {
        guard let buckets = discoveredBuckets?.screenTimeBuckets, !buckets.isEmpty else { return [] }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var allEvents: [AWEvent] = []

        // Fetch from all screen time buckets (one per iOS device)
        for bucket in buckets {
            let urlStr = "http://\(desktopIP):\(port)/api/0/buckets/\(bucket)/events?start=\(formatter.string(from: start))&end=\(formatter.string(from: end))&limit=-1"
            guard let url = URL(string: urlStr) else { continue }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else { continue }

                let events = try parseScreenTimeEvents(data)
                if !events.isEmpty {
                    print("[ActivityWatch] Fetched \(events.count) screen time events from \(bucket)")
                    allEvents.append(contentsOf: events)
                }
            } catch {
                print("[ActivityWatch] Failed to fetch screen time from \(bucket): \(error.localizedDescription)")
            }
        }

        print("[ActivityWatch] Total screen time events: \(allEvents.count)")
        return allEvents.sorted { $0.timestamp < $1.timestamp }
    }

    private func parseScreenTimeEvents(_ data: Data) throws -> [AWEvent] {
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

            let rawApp = (eventData["app"] as? String) ?? "Unknown"

            // Filter out iOS system noise (lock screen, springboard, screenshots, etc.)
            let systemPrefixes = ["com.apple.springboard", "com.apple.SleepLockScreen",
                                  "com.apple.ScreenshotServicesService", "com.apple.ClockAngel",
                                  "com.apple.CarPlayTemplateUIHost", "com.apple.Spotlight",
                                  "com.apple.InCallService", "com.apple.TelephonyUtilities"]
            if systemPrefixes.contains(where: { rawApp.hasPrefix($0) }) { return nil }

            let app = Self.resolveAppName(rawApp)
            let title = (eventData["title"] as? String) ?? ""

            return AWEvent(
                id: "st-\(id)",
                timestamp: timestamp,
                duration: duration,
                appName: app,
                windowTitle: title,
                url: nil,
                sourceDevice: .iphone
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

    /// Fetch window events from the aw-watcher-window bucket only.
    private func fetchWindowEvents(from start: Date, to end: Date) async throws -> [AWEvent] {
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

    /// Concurrently fetch from all buckets: window, web-chrome, and screen time.
    private func fetchEventsInRange(from start: Date, to end: Date) async throws -> [AWEvent] {
        // Concurrent fetch: window events + screen time events
        async let windowTask = fetchWindowEvents(from: start, to: end)
        async let screenTimeTask = fetchScreenTimeEvents(from: start, to: end)

        var windowEvents = try await windowTask
        let screenTimeEvents = await screenTimeTask

        // Enrich Mac browser events with Chrome extension URLs
        windowEvents = await enrichWithWebEvents(windowEvents, from: start, to: end)

        // Merge all event streams
        let allEvents = (windowEvents + screenTimeEvents)
            .sorted { $0.timestamp < $1.timestamp }

        return allEvents
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

            // Filter out system apps (loginwindow, WindowServer, etc.)
            if Self.systemIgnoreList.contains(app) { return nil }

            let title = (eventData["title"] as? String) ?? ""

            return AWEvent(
                id: "\(id)",
                timestamp: timestamp,
                duration: duration,
                appName: app,
                windowTitle: title,
                url: nil,
                sourceDevice: .mac
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
