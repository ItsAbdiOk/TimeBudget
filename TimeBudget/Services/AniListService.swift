import Foundation

struct AniListActivity: Identifiable {
    let id: Int
    let mediaTitle: String
    let progress: String      // e.g. "read chapter 45" or "watched episode 12"
    let chaptersRead: Int
    let createdAt: Date
    let ismanga: Bool
}

final class AniListService {
    static let shared = AniListService()

    var username: String {
        UserDefaults.standard.string(forKey: "anilist_username") ?? ""
    }
    var minutesPerChapter: Int {
        let stored = UserDefaults.standard.integer(forKey: "anilist_minutes_per_chapter")
        return stored > 0 ? stored : 4
    }

    var isConfigured: Bool { !username.isEmpty }

    private let apiURL = URL(string: "https://graphql.anilist.co")!

    // MARK: - Cache

    /// Cached user ID to avoid re-fetching every time
    private var cachedUserId: Int?

    /// In-memory cache of fetched activities, keyed by date string "yyyy-MM-dd"
    private var activityCache: [String: [AniListActivity]] = [:]

    /// When the cache was last refreshed
    private(set) var lastSyncDate: Date?

    // MARK: - Public API

    /// Return cached activities for a date, or empty if not yet synced.
    /// Does NOT hit the network — call `syncReadingActivity` first.
    func cachedReadingActivity(for date: Date) -> [AniListActivity] {
        let key = Self.cacheKey(for: date)
        return activityCache[key] ?? []
    }

    /// Fetch from AniList API and update the cache. Call this on:
    /// - Pull-to-refresh on dashboard
    /// - BGAppRefreshTask overnight
    /// - App foreground (at most once per hour)
    func syncReadingActivity(for date: Date) async {
        guard isConfigured else { return }
        do {
            let activities = try await fetchReadingActivity(for: date)
            let key = Self.cacheKey(for: date)
            activityCache[key] = activities
            lastSyncDate = Date()
        } catch {
            // Network failure is fine — we just use stale cache
        }
    }

    /// Sync the last N days (for background refresh)
    func syncRecentActivity(days: Int = 7) async {
        let calendar = Calendar.current
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            await syncReadingActivity(for: date)
        }
    }

    /// Whether we should sync (throttle to once per hour)
    var shouldSync: Bool {
        guard let last = lastSyncDate else { return true }
        return Date().timeIntervalSince(last) > 3600
    }

    // MARK: - Network Fetches (always async, never on main thread)

    private func fetchReadingActivity(for date: Date) async throws -> [AniListActivity] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let startTimestamp = Int(startOfDay.timeIntervalSince1970)
        let endTimestamp = Int(endOfDay.timeIntervalSince1970)

        let userId = try await resolveUserId()
        return try await fetchActivities(userId: userId, from: startTimestamp, to: endTimestamp)
    }

    func fetchReadingActivity(from startDate: Date, to endDate: Date) async throws -> [AniListActivity] {
        guard isConfigured else { return [] }
        let startTimestamp = Int(startDate.timeIntervalSince1970)
        let endTimestamp = Int(endDate.timeIntervalSince1970)

        let userId = try await resolveUserId()
        return try await fetchActivities(userId: userId, from: startTimestamp, to: endTimestamp)
    }

    // MARK: - Private

    private func resolveUserId() async throws -> Int {
        if let cached = cachedUserId { return cached }

        let query = """
        query {
            User(name: "\(username)") {
                id
            }
        }
        """

        let data = try await executeQuery(query)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["User"] as? [String: Any],
              let userId = user["id"] as? Int else {
            throw AniListError.invalidResponse
        }

        cachedUserId = userId
        return userId
    }

    private func fetchActivities(userId: Int, from startTimestamp: Int, to endTimestamp: Int) async throws -> [AniListActivity] {
        var allActivities: [AniListActivity] = []
        var page = 1
        let perPage = 50

        while true {
            let query = """
            query ($userId: Int, $createdAtGreater: Int, $createdAtLesser: Int, $page: Int, $perPage: Int) {
                Page(page: $page, perPage: $perPage) {
                    pageInfo { hasNextPage }
                    activities(userId: $userId, type: MEDIA_LIST, createdAt_greater: $createdAtGreater, createdAt_lesser: $createdAtLesser, sort: ID_DESC) {
                        ... on ListActivity {
                            id
                            status
                            progress
                            createdAt
                            media {
                                title {
                                    english
                                    userPreferred
                                }
                                type
                                format
                            }
                        }
                    }
                }
            }
            """

            let variables: [String: Any] = [
                "userId": userId,
                "createdAtGreater": startTimestamp,
                "createdAtLesser": endTimestamp,
                "page": page,
                "perPage": perPage
            ]

            let data = try await executeQuery(query, variables: variables)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let pageObj = dataObj["Page"] as? [String: Any],
                  let activities = pageObj["activities"] as? [[String: Any]] else {
                break
            }

            let parsed = activities.compactMap { activity -> AniListActivity? in
                guard let id = activity["id"] as? Int,
                      let createdAtInt = activity["createdAt"] as? Int,
                      let media = activity["media"] as? [String: Any],
                      let title = media["title"] as? [String: Any],
                      let mediaType = media["type"] as? String else {
                    return nil
                }

                let isManga = mediaType == "MANGA"
                guard isManga else { return nil }

                // Filter out non-reading activities (dropped, completed, plans to read, paused, etc.)
                let status = activity["status"] as? String ?? ""
                let readingStatuses: Set<String> = ["read chapter", "reread chapter"]
                guard readingStatuses.contains(status.lowercased()) else { return nil }

                // Prefer English title, fall back to userPreferred
                let mediaTitle = (title["english"] as? String) ?? (title["userPreferred"] as? String) ?? "Unknown"
                let progress = activity["progress"] as? String ?? ""
                let chapters = parseChapters(progress: progress, status: status)

                return AniListActivity(
                    id: id,
                    mediaTitle: mediaTitle,
                    progress: "\(status) \(progress)",
                    chaptersRead: max(chapters, 1),
                    createdAt: Date(timeIntervalSince1970: TimeInterval(createdAtInt)),
                    ismanga: isManga
                )
            }

            allActivities.append(contentsOf: parsed)

            // Check if there are more pages
            let pageInfo = pageObj["pageInfo"] as? [String: Any]
            let hasNextPage = pageInfo?["hasNextPage"] as? Bool ?? false
            guard hasNextPage, !activities.isEmpty else { break }
            page += 1
        }

        return allActivities
    }

    private func parseChapters(progress: String, status: String) -> Int {
        guard !progress.isEmpty else { return 1 }

        if progress.contains("-") {
            let parts = progress.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, let start = Int(parts[0]), let end = Int(parts[1]) {
                return max(end - start + 1, 1)
            }
        }

        if Int(progress) != nil {
            return 1
        }

        return 1
    }

    private func executeQuery(_ query: String, variables: [String: Any]? = nil) async throws -> Data {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15 // Don't hang on slow networks

        var body: [String: Any] = ["query": query]
        if let variables = variables {
            body["variables"] = variables
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AniListError.requestFailed
        }

        return data
    }

    private static func cacheKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum AniListError: Error {
    case invalidResponse
    case requestFailed
}
