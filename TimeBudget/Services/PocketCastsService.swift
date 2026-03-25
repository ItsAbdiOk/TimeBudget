import Foundation

// MARK: - Models

struct PocketCastsEpisode: Identifiable {
    let id: String
    let title: String
    let podcastTitle: String
    let duration: TimeInterval       // total duration in seconds
    let playedUpTo: TimeInterval     // how far into the episode the user listened
    let playingStatus: Int           // 2 = in progress, 3 = completed
    let publishedDate: Date
    let lastPlayedAt: Date?

    /// Whether this episode was meaningfully listened to (completed or >5 min played)
    var wasListened: Bool {
        playingStatus == 3 || playedUpTo >= 300 || (duration > 0 && playedUpTo / duration > 0.25)
    }

    /// Actual listening time in minutes
    var listenedMinutes: Int {
        if playingStatus == 3 {
            return Int(duration / 60)
        }
        return Int(playedUpTo / 60)
    }
}

// MARK: - Errors

enum PocketCastsError: LocalizedError {
    case noToken
    case invalidResponse
    case requestFailed(statusCode: Int)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noToken: return "No Pocket Casts token configured"
        case .invalidResponse: return "Invalid response from Pocket Casts"
        case .requestFailed(let code): return "Request failed with status \(code)"
        case .unauthorized: return "Token expired or invalid"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}

// MARK: - Service

final class PocketCastsService {
    static let shared = PocketCastsService()

    private let historyURL = URL(string: "https://api.pocketcasts.com/user/history")!
    private let profileURL = URL(string: "https://api.pocketcasts.com/user/profile")!
    private let loginURL = URL(string: "https://api.pocketcasts.com/user/login")!

    // MARK: - Cache

    private var cachedEpisodes: [PocketCastsEpisode] = []
    private(set) var lastSyncDate: Date?

    var shouldSync: Bool {
        guard let last = lastSyncDate else { return true }
        return Date().timeIntervalSince(last) > 3600 // 1 hour throttle
    }

    // MARK: - Token Management (Keychain-backed)

    var isConfigured: Bool {
        KeychainManager.load() != nil
    }

    var token: String? {
        KeychainManager.load()
    }

    @discardableResult
    func saveToken(_ token: String) -> Bool {
        cachedEpisodes = [] // Clear cache when token changes
        lastSyncDate = nil
        return KeychainManager.save(token: token)
    }

    func clearToken() {
        KeychainManager.delete()
        cachedEpisodes = []
        lastSyncDate = nil
    }

    // MARK: - Login (email + password → token)

    /// Authenticate with Pocket Casts and store the token in Keychain.
    /// Returns the email on success for UI confirmation.
    func login(email: String, password: String) async throws -> String {
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PocketCastsError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw PocketCastsError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PocketCastsError.requestFailed(statusCode: httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bearerToken = json["token"] as? String else {
            throw PocketCastsError.invalidResponse
        }

        saveToken(bearerToken)
        return email
    }

    // MARK: - Public API

    /// Fetch listening history and return episodes listened today
    func fetchTodayEpisodes() async throws -> [PocketCastsEpisode] {
        guard isConfigured else { throw PocketCastsError.noToken }
        if !shouldSync, !cachedEpisodes.isEmpty { return todayEpisodes(from: cachedEpisodes) }

        let episodes = try await fetchHistory()
        cachedEpisodes = episodes
        lastSyncDate = Date()
        return todayEpisodes(from: episodes)
    }

    /// Fetch all cached episodes for a date range (for heatmaps / trends)
    func fetchEpisodes(from start: Date, to end: Date) async throws -> [PocketCastsEpisode] {
        guard isConfigured else { throw PocketCastsError.noToken }

        // Sync if stale
        if shouldSync {
            cachedEpisodes = try await fetchHistory()
            lastSyncDate = Date()
        }

        return cachedEpisodes.filter { episode in
            guard let played = episode.lastPlayedAt else { return false }
            return played >= start && played < end && episode.wasListened
        }
    }

    /// Test the connection with the stored token
    func testConnection() async throws -> Bool {
        guard let bearerToken = token else { throw PocketCastsError.noToken }

        var request = URLRequest(url: profileURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PocketCastsError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw PocketCastsError.unauthorized
        }

        return (200...299).contains(httpResponse.statusCode)
    }

    // MARK: - Private

    private func fetchHistory() async throws -> [PocketCastsEpisode] {
        guard let bearerToken = token else { throw PocketCastsError.noToken }

        var request = URLRequest(url: historyURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        // The history endpoint accepts an empty body or optional pagination
        request.httpBody = "{}".data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw PocketCastsError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PocketCastsError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw PocketCastsError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PocketCastsError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try parseHistory(data)
    }

    private func parseHistory(_ data: Data) throws -> [PocketCastsEpisode] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let episodes = json["episodes"] as? [[String: Any]] else {
            // Log raw response for debugging
            if let raw = String(data: data.prefix(500), encoding: .utf8) {
                print("[PocketCasts] Unexpected response format: \(raw)")
            }
            throw PocketCastsError.invalidResponse
        }

        // Debug: log first episode's raw fields
        if let first = episodes.first {
            print("[PocketCasts] Sample episode keys: \(first.keys.sorted())")
            print("[PocketCasts] Sample episode: title=\(first["title"] ?? "nil"), lastPlayingTime=\(first["lastPlayingTime"] ?? "nil"), playedUpTo=\(first["playedUpTo"] ?? "nil"), duration=\(first["duration"] ?? "nil"), playingStatus=\(first["playingStatus"] ?? "nil")")
        }
        print("[PocketCasts] Total episodes in response: \(episodes.count)")

        return episodes.compactMap { ep -> PocketCastsEpisode? in
            guard let uuid = ep["uuid"] as? String,
                  let title = ep["title"] as? String,
                  let podcastTitle = ep["podcastTitle"] as? String else {
                return nil
            }

            let duration = (ep["duration"] as? Double) ?? 0
            let playedUpTo = (ep["playedUpTo"] as? Double) ?? 0
            let playingStatus = (ep["playingStatus"] as? Int) ?? 0

            // Parse dates
            let publishedDate: Date
            if let pubStr = ep["published"] as? String {
                publishedDate = Self.parseDate(pubStr) ?? Date.distantPast
            } else {
                publishedDate = Date.distantPast
            }

            // Try multiple field names and formats for last played date
            let lastPlayedAt: Date?
            if let playStr = ep["lastPlayingTime"] as? String {
                lastPlayedAt = Self.parseDate(playStr)
            } else if let playStr = ep["lastPlayedAt"] as? String {
                lastPlayedAt = Self.parseDate(playStr)
            } else if let epochMs = ep["lastPlayingTime"] as? Double {
                lastPlayedAt = Date(timeIntervalSince1970: epochMs / 1000.0)
            } else if let epochMs = ep["lastPlayingTime"] as? Int {
                lastPlayedAt = Date(timeIntervalSince1970: Double(epochMs) / 1000.0)
            } else {
                // No played timestamp — don't fabricate one with Date(),
                // as that makes old episodes appear as "played today" on every sync
                lastPlayedAt = nil
            }

            return PocketCastsEpisode(
                id: uuid,
                title: title,
                podcastTitle: podcastTitle,
                duration: duration,
                playedUpTo: playedUpTo,
                playingStatus: playingStatus,
                publishedDate: publishedDate,
                lastPlayedAt: lastPlayedAt
            )
        }
    }

    private func todayEpisodes(from episodes: [PocketCastsEpisode]) -> [PocketCastsEpisode] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return episodes.filter { ep in
            guard let played = ep.lastPlayedAt else { return false }
            return played >= startOfDay && played < endOfDay && ep.wasListened
        }
    }

    // Pocket Casts uses ISO 8601 dates
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ string: String) -> Date? {
        if let d = iso8601.date(from: string) { return d }
        if let d = iso8601NoFraction.date(from: string) { return d }
        // Fallback: epoch milliseconds as string (e.g. "1711324800000")
        if let ms = Double(string), ms > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: ms / 1000.0)
        }
        // Fallback: epoch seconds as string
        if let s = Double(string), s > 1_000_000_000 {
            return Date(timeIntervalSince1970: s)
        }
        return nil
    }
}
