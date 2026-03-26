import Foundation
import FoundationModels

// MARK: - Categorization Models

@available(iOS 26, *)
struct UncategorizedItem: Codable {
    let id: String
    let app: String
    let title: String
    let site: String?
    let durationMinutes: Int
}

@available(iOS 26, *)
struct CategorizedItem: Codable {
    let id: String
    let category: String
    let confidence: Double
}

@available(iOS 26, *)
struct CategorizationResult: Codable {
    let items: [CategorizedItem]
}

// MARK: - Conflict Resolution Models

@available(iOS 26, *)
struct ConflictGroup: Codable {
    let groupId: String
    let overlapStart: String
    let overlapEnd: String
    let candidates: [ConflictCandidate]
}

@available(iOS 26, *)
struct ConflictCandidate: Codable {
    let source: String
    let category: String
    let metadata: [String: String]
    let confidence: Double
}

@available(iOS 26, *)
struct ConflictResolution: Codable {
    let groupId: String
    let winnerSource: String
    let winnerCategory: String
    let reasoning: String
}

@available(iOS 26, *)
struct ConflictResolutionResult: Codable {
    let resolutions: [ConflictResolution]
}

// MARK: - Errors

@available(iOS 26, *)
enum IntelligenceError: LocalizedError {
    case modelUnavailable
    case invalidResponse
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable: return "Apple Intelligence is not available on this device"
        case .invalidResponse: return "The model returned an unexpected response"
        case .decodingFailed(let detail): return "Failed to decode model output: \(detail)"
        }
    }
}

// MARK: - Service

@available(iOS 26, *)
actor IntelligenceService {
    static let shared = IntelligenceService()

    private var session: LanguageModelSession?
    private(set) var isReady = false

    /// Initialize the model session on a background thread.
    func warmUp() async {
        guard SystemLanguageModel.default.isAvailable else {
            print("[Intelligence] Model not available on this device")
            return
        }
        session = LanguageModelSession()
        isReady = true
        print("[Intelligence] Model warmed up and ready")
    }

    /// Simple connectivity test — confirm the model responds.
    func smokeTest() async throws -> String {
        guard session != nil else {
            throw IntelligenceError.modelUnavailable
        }
        let testSession = LanguageModelSession(instructions: "You are a system status reporter. When asked for status, respond with only the word OK. Nothing else.")
        let response = try await testSession.respond(to: "Status?")
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Model responded (empty)" : text
    }

    // MARK: - Categorization Engine

    func categorize(items: [UncategorizedItem], validCategories: [String]) async throws -> [CategorizedItem] {
        guard isReady else { throw IntelligenceError.modelUnavailable }

        let categoryList = validCategories.joined(separator: ", ")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let itemsData = try encoder.encode(items)
        let itemsString = String(data: itemsData, encoding: .utf8) ?? "[]"

        let systemPrompt = """
            You are a time-tracking categorization engine. You receive desktop activity events \
            (app name, window title, website) and must classify each into exactly one category.

            Valid categories: \(categoryList)

            Rules:
            - IDEs, terminals, code editors → "Deep Work"
            - Documentation, Stack Overflow, GitHub → "Deep Work"
            - Notion, Google Docs, writing tools → "Work"
            - Meetings, Zoom, Google Meet → "Meetings"
            - Reddit, social media feeds, TikTok, Instagram → "Distraction"
            - News sites, casual browsing → "Neutral"
            - If unsure, use "Desk Time" as the safe default

            YouTube rules (use the video TITLE to decide):
            - Tutorials, coding videos, conference talks, lectures, documentation → "Deep Work"
            - Productivity, educational, how-to, tech reviews → "Productive"
            - Music, lo-fi, ambient (background while working) → "Neutral"
            - Entertainment, vlogs, shorts, gaming, reaction videos, drama → "Distraction"

            Respond with ONLY a JSON object matching this schema:
            {"items": [{"id": "<same id from input>", "category": "<one of the valid categories>", "confidence": <0.0 to 1.0>}]}

            No markdown, no explanation, no code fences. Pure JSON only.
            """

        let userPrompt = "Categorize these desktop activities:\n\(itemsString)"

        let catSession = LanguageModelSession(instructions: systemPrompt)
        let response = try await catSession.respond(to: userPrompt)
        let responseText = response.content

        print("[Intelligence] Categorization response: \(responseText.prefix(200))")

        // The model may return {"items": [...]} or just [...] — handle both
        let items: [CategorizedItem]
        if let parsed = try? Self.parseJSON(responseText, as: CategorizationResult.self) {
            items = parsed.items
        } else {
            items = try Self.parseJSON(responseText, as: [CategorizedItem].self)
        }

        let validSet = Set(validCategories)
        return items.filter { validSet.contains($0.category) }
    }

    // MARK: - Conflict Resolution Engine

    func resolveConflicts(groups: [ConflictGroup]) async throws -> [ConflictResolution] {
        guard isReady else { throw IntelligenceError.modelUnavailable }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let groupsData = try encoder.encode(groups)
        let groupsString = String(data: groupsData, encoding: .utf8) ?? "[]"

        let systemPrompt = """
            You are a time-tracking conflict resolver. You receive groups of overlapping \
            time entries from different data sources that cover the same time period. \
            For each group, pick the single most likely true activity.

            Hierarchy of Truth (when confidence is similar):
            1. Explicit user actions (manual entries, focus sessions) — always win
            2. Biometric data (HealthKit sleep, workouts) — body doesn't lie
            3. Calendar events — scheduled commitments
            4. Active engagement signals (podcast playing, manga reading, code editing) — user chose this
            5. Passive observation (desktop window titles, location) — could be background noise

            Key heuristics:
            - Coding in Xcode + podcast playing → coding wins (podcast is background)
            - Calendar meeting + Zoom on desktop → meeting wins (they corroborate)
            - Chrome on YouTube + podcast playing → podcast wins (YouTube might be music)
            - Higher confidence values should be preferred when hierarchy is tied

            Respond with ONLY a JSON object:
            {"resolutions": [{"groupId": "<id>", "winnerSource": "<source>", "winnerCategory": "<category>", "reasoning": "<1 sentence>"}]}

            No markdown, no explanation. Pure JSON only.
            """

        let userPrompt = "Resolve these time conflicts:\n\(groupsString)"

        let conflictSession = LanguageModelSession(instructions: systemPrompt)
        let response = try await conflictSession.respond(to: userPrompt)
        let responseText = response.content

        print("[Intelligence] Conflict resolution response: \(responseText.prefix(200))")

        // The model may return {"resolutions": [...]} or just [...] — handle both
        if let parsed = try? Self.parseJSON(responseText, as: ConflictResolutionResult.self) {
            return parsed.resolutions
        } else {
            return try Self.parseJSON(responseText, as: [ConflictResolution].self)
        }
    }

    // MARK: - JSON Parsing

    private static func parseJSON<T: Decodable>(_ text: String, as type: T.Type) throws -> T {
        // Strip accidental markdown fences
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw IntelligenceError.decodingFailed("Response was not valid UTF-8")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw IntelligenceError.decodingFailed(error.localizedDescription)
        }
    }
}
