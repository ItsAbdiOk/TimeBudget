import Foundation

struct LeetCodeStats {
    let totalSolved: Int
    let easySolved: Int
    let mediumSolved: Int
    let hardSolved: Int
    let streak: Int
    let ranking: Int
}

struct LeetCodeSubmission: Identifiable {
    let id: String
    let title: String
    let timestamp: Date
    let topicTag: String
}

final class LeetCodeService {
    static let shared = LeetCodeService()

    var username: String {
        UserDefaults.standard.string(forKey: "leetcode_username") ?? ""
    }

    var isConfigured: Bool { !username.isEmpty }
    private let apiURL = URL(string: "https://leetcode.com/graphql")!

    // MARK: - Cache

    private var cachedStats: LeetCodeStats?
    private var cachedCalendar: [Date: Int]?
    private var cachedSubmissions: [LeetCodeSubmission]?
    private(set) var lastSyncDate: Date?

    var shouldSync: Bool {
        guard let last = lastSyncDate else { return true }
        return Date().timeIntervalSince(last) > 3600
    }

    // MARK: - Public API

    func fetchStats() async throws -> LeetCodeStats {
        guard isConfigured else { throw LeetCodeError.invalidResponse }
        if let cached = cachedStats, !shouldSync { return cached }

        let query = """
        query {
            matchedUser(username: "\(username)") {
                submitStatsGlobal {
                    acSubmissionNum { difficulty count }
                }
                profile { ranking }
            }
        }
        """

        let data = try await executeQuery(query)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["matchedUser"] as? [String: Any],
              let statsObj = user["submitStatsGlobal"] as? [String: Any],
              let submissions = statsObj["acSubmissionNum"] as? [[String: Any]],
              let profile = user["profile"] as? [String: Any],
              let ranking = profile["ranking"] as? Int else {
            throw LeetCodeError.invalidResponse
        }

        var easy = 0, medium = 0, hard = 0, total = 0
        for entry in submissions {
            let difficulty = entry["difficulty"] as? String ?? ""
            let count = entry["count"] as? Int ?? 0
            switch difficulty {
            case "All": total = count
            case "Easy": easy = count
            case "Medium": medium = count
            case "Hard": hard = count
            default: break
            }
        }

        let stats = LeetCodeStats(
            totalSolved: total,
            easySolved: easy,
            mediumSolved: medium,
            hardSolved: hard,
            streak: 0,
            ranking: ranking
        )
        cachedStats = stats
        return stats
    }

    func fetchSubmissionCalendar() async throws -> [Date: Int] {
        guard isConfigured else { return [:] }
        if let cached = cachedCalendar, !shouldSync { return cached }

        let query = """
        query {
            matchedUser(username: "\(username)") {
                userCalendar { submissionCalendar streak }
            }
        }
        """

        let data = try await executeQuery(query)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["matchedUser"] as? [String: Any],
              let calendar = user["userCalendar"] as? [String: Any],
              let calendarStr = calendar["submissionCalendar"] as? String else {
            throw LeetCodeError.invalidResponse
        }

        guard let calendarData = calendarStr.data(using: .utf8),
              let calendarDict = try JSONSerialization.jsonObject(with: calendarData) as? [String: Int] else {
            throw LeetCodeError.invalidResponse
        }

        var result: [Date: Int] = [:]
        for (timestampStr, count) in calendarDict {
            if let timestamp = Double(timestampStr) {
                let date = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: timestamp))
                result[date] = count
            }
        }

        cachedCalendar = result
        lastSyncDate = Date()
        return result
    }

    func fetchRecentSubmissions(limit: Int = 10) async throws -> [LeetCodeSubmission] {
        guard isConfigured else { return [] }
        if let cached = cachedSubmissions, !shouldSync { return cached }

        let query = """
        query {
            recentAcSubmissionList(username: "\(username)", limit: \(limit)) {
                id title titleSlug timestamp
            }
        }
        """

        let data = try await executeQuery(query)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let list = dataObj["recentAcSubmissionList"] as? [[String: Any]] else {
            throw LeetCodeError.invalidResponse
        }

        // Collect title slugs to batch-fetch topic tags
        let entries = list.compactMap { entry -> (id: String, title: String, slug: String, timestamp: Date)? in
            guard let id = entry["id"] as? String,
                  let title = entry["title"] as? String,
                  let timestampStr = entry["timestamp"] as? String,
                  let timestamp = Double(timestampStr),
                  let slug = entry["titleSlug"] as? String else { return nil }
            return (id: id, title: title, slug: slug, timestamp: Date(timeIntervalSince1970: timestamp))
        }

        // Fetch topic tags for each problem (deduplicated by slug)
        let uniqueSlugs = Array(Set(entries.map { $0.slug }))
        var tagsBySlug: [String: String] = [:]

        // Fetch tags in parallel (up to 5 at a time to avoid rate limits)
        await withTaskGroup(of: (String, String).self) { group in
            for slug in uniqueSlugs {
                group.addTask { [self] in
                    let tag = (try? await self.fetchTopicTag(for: slug)) ?? ""
                    return (slug, tag)
                }
            }
            for await (slug, tag) in group {
                tagsBySlug[slug] = tag
            }
        }

        let submissions = entries.map { entry in
            LeetCodeSubmission(
                id: entry.id,
                title: entry.title,
                timestamp: entry.timestamp,
                topicTag: tagsBySlug[entry.slug] ?? ""
            )
        }

        cachedSubmissions = submissions
        return submissions
    }

    /// Fetch the first topic tag for a problem by its slug
    private func fetchTopicTag(for titleSlug: String) async throws -> String {
        let query = """
        query {
            question(titleSlug: "\(titleSlug)") {
                topicTags { name }
            }
        }
        """

        let data = try await executeQuery(query)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let question = dataObj["question"] as? [String: Any],
              let tags = question["topicTags"] as? [[String: Any]] else {
            return ""
        }

        // Return the first topic tag name
        return (tags.first?["name"] as? String) ?? ""
    }

    // MARK: - Private

    private func executeQuery(_ query: String) async throws -> Data {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let body: [String: Any] = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LeetCodeError.requestFailed
        }

        return data
    }
}

enum LeetCodeError: Error {
    case invalidResponse
    case requestFailed
}
