import Foundation

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

    var isConfigured: Bool { !desktopIP.isEmpty && !hostname.isEmpty }

    let port = 5600

    // MARK: - Discovered Buckets

    struct DiscoveredBuckets {
        var windowBucket: String?
        var webChromeBuckets: [String] = []
        var screenTimeBuckets: [String] = []
        var hostname: String?
    }

    var discoveredBuckets: DiscoveredBuckets?

    // MARK: - Cache

    private var cachedBlocks: [AWActivityBlock] = []
    private var cachedDate: Date?
    private(set) var lastSyncDate: Date?

    var shouldSync: Bool {
        guard let last = lastSyncDate else { return true }
        return Date().timeIntervalSince(last) > 3600
    }

    // MARK: - URLSession

    lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    // MARK: - Bucket Discovery

    private var lastBucketDiscovery: Date?

    func ensureBucketsDiscovered() async {
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

    var bucketId: String { "aw-watcher-window_\(hostname)" }

    // MARK: - Public API

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

    func fetchBlocks(for date: Date) async throws -> [AWActivityBlock] {
        guard isConfigured else { throw ActivityWatchError.notConfigured }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let events = try await fetchEventsInRange(from: start, to: end)
        let meaningful = events.filter { $0.duration >= 120 }
        return bundleIntoBlocks(meaningful)
    }

    func fetchBlocks(from start: Date, to end: Date) async throws -> [AWActivityBlock] {
        guard isConfigured else { throw ActivityWatchError.notConfigured }
        await ensureBucketsDiscovered()

        let events = try await fetchEventsInRange(from: start, to: end)
        let meaningful = events.filter { $0.duration >= 120 }
        return bundleIntoBlocks(meaningful)
    }

    func fetchRawEvents(for date: Date) async throws -> [AWEvent] {
        guard isConfigured else { throw ActivityWatchError.notConfigured }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return try await fetchEventsInRange(from: start, to: end)
    }

    // MARK: - Event Orchestration

    func fetchEventsInRange(from start: Date, to end: Date) async throws -> [AWEvent] {
        async let windowTask = fetchWindowEvents(from: start, to: end)
        async let screenTimeTask = fetchScreenTimeEvents(from: start, to: end)

        var windowEvents = try await windowTask
        let screenTimeEvents = await screenTimeTask

        windowEvents = await enrichWithWebEvents(windowEvents, from: start, to: end)

        return (windowEvents + screenTimeEvents).sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Bundling

    func bundleIntoBlocks(_ events: [AWEvent]) -> [AWActivityBlock] {
        guard !events.isEmpty else { return [] }

        let maxGap: TimeInterval = 5 * 60
        var blocks: [AWActivityBlock] = []
        var currentEvents: [AWEvent] = [events[0]]
        var blockStart = events[0].timestamp

        for event in events.dropFirst() {
            let prevEnd = currentEvents.last!.timestamp.addingTimeInterval(currentEvents.last!.duration)
            let gap = event.timestamp.timeIntervalSince(prevEnd)

            if gap > maxGap {
                blocks.append(makeBlock(events: currentEvents, start: blockStart))
                currentEvents = [event]
                blockStart = event.timestamp
            } else {
                currentEvents.append(event)
            }
        }

        if !currentEvents.isEmpty {
            blocks.append(makeBlock(events: currentEvents, start: blockStart))
        }
        return blocks
    }

    private func makeBlock(events: [AWEvent], start: Date) -> AWActivityBlock {
        let lastEvent = events.last!
        let end = lastEvent.timestamp.addingTimeInterval(lastEvent.duration)

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
        let tier = ProductivityClassifier.classify(app: topApp, site: topSite)

        return AWActivityBlock(
            start: start, end: end,
            category: tier.rawValue,
            topApp: topApp, topSite: topSite,
            events: events
        )
    }
}
