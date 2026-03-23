import Foundation
import Security

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

    /// Whether this episode was meaningfully listened to (completed or >50% played)
    var wasListened: Bool {
        playingStatus == 3 || (duration > 0 && playedUpTo / duration > 0.5)
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

// MARK: - Keychain Helper

private enum KeychainHelper {
    static let service = "com.timebudget.pocketcasts"
    static let account = "bearer_token"

    static func save(token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }

        // Delete existing first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Insert new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Service

final class PocketCastsService {
    static let shared = PocketCastsService()

    private let historyURL = URL(string: "https://api.pocketcasts.com/user/history")!
    private let profileURL = URL(string: "https://api.pocketcasts.com/user/profile")!

    // MARK: - Cache

    private var cachedEpisodes: [PocketCastsEpisode] = []
    private(set) var lastSyncDate: Date?

    var shouldSync: Bool {
        guard let last = lastSyncDate else { return true }
        return Date().timeIntervalSince(last) > 3600 // 1 hour throttle
    }

    // MARK: - Token Management (Keychain-backed)

    var isConfigured: Bool {
        KeychainHelper.load() != nil
    }

    var token: String? {
        KeychainHelper.load()
    }

    @discardableResult
    func saveToken(_ token: String) -> Bool {
        cachedEpisodes = [] // Clear cache when token changes
        lastSyncDate = nil
        return KeychainHelper.save(token: token)
    }

    func clearToken() {
        KeychainHelper.delete()
        cachedEpisodes = []
        lastSyncDate = nil
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
            throw PocketCastsError.invalidResponse
        }

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

            let lastPlayedAt: Date?
            if let playStr = ep["lastPlayingTime"] as? String {
                lastPlayedAt = Self.parseDate(playStr)
            } else {
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
        iso8601.date(from: string) ?? iso8601NoFraction.date(from: string)
    }
}
