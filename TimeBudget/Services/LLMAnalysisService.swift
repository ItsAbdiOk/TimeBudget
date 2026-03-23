import Foundation

// MARK: - Productivity Tag

enum ProductivityTag: String, Codable {
    case productive  = "productive"
    case distracted  = "distracted"
    case onBreak     = "break"
    case unknown     = "unknown"

    var label: String {
        switch self {
        case .productive: return "Productive"
        case .distracted: return "Distracted"
        case .onBreak:    return "Break"
        case .unknown:    return "Untagged"
        }
    }

    var systemImage: String {
        switch self {
        case .productive: return "checkmark.circle.fill"
        case .distracted: return "exclamationmark.circle.fill"
        case .onBreak:    return "cup.and.saucer.fill"
        case .unknown:    return "circle.dotted"
        }
    }
}

// MARK: - Daily Narrative Result

struct DailyNarrativeResult {
    let narrative: String
    let suggestion: String
}

// MARK: - Service

/// Builds prompts from app data and calls the configured LLM backend.
/// Handles both features: daily narrative analysis and ActivityWatch productivity tagging.
final class LLMAnalysisService {
    static let shared = LLMAnalysisService()

    // MARK: - Daily Narrative

    /// Generate a natural-language summary of the user's day.
    /// - Parameters:
    ///   - entries: Today's TimeEntry records
    ///   - sleepMinutes: Hours slept last night
    ///   - steps: Step count for the day
    ///   - workoutMinutes: Total workout duration
    ///   - meetingMinutes: Total meeting/calendar time
    ///   - awTopApps: Top desktop apps from ActivityWatch (if available)
    ///   - dailyScore: Overall day score (0–100) if available
    func generateDailyNarrative(
        entries: [TimeEntry],
        sleepMinutes: Int,
        steps: Int,
        workoutMinutes: Int,
        meetingMinutes: Int,
        awTopApps: [String],
        dailyScore: Int?
    ) async throws -> DailyNarrativeResult {
        guard let llm = LLMServiceFactory.current else {
            throw LLMError.notConfigured
        }

        let prompt = buildNarrativePrompt(
            entries: entries,
            sleepMinutes: sleepMinutes,
            steps: steps,
            workoutMinutes: workoutMinutes,
            meetingMinutes: meetingMinutes,
            awTopApps: awTopApps,
            dailyScore: dailyScore
        )

        let raw = try await llm.complete(prompt: prompt)
        return parseNarrativeResponse(raw)
    }

    // MARK: - ActivityWatch Productivity Tagging

    /// Tag a list of ActivityWatch blocks as productive / distracted / break.
    /// Falls back to the existing heuristic (Deep Work / Desk Time) if LLM is not configured
    /// or if the request fails.
    func tagProductivity(blocks: [AWActivityBlock]) async throws -> [AWActivityBlock] {
        guard LLMServiceFactory.isConfigured, let llm = LLMServiceFactory.current else {
            // No LLM configured — return with heuristic-derived tags
            return blocks.map { applyHeuristicTag($0) }
        }

        guard !blocks.isEmpty else { return [] }

        let prompt = buildTaggingPrompt(blocks: blocks)

        do {
            let raw = try await llm.complete(prompt: prompt)
            let tags = parseTaggingResponse(raw)
            return blocks.map { block in
                let tag = tags[block.id.uuidString] ?? heuristicTag(for: block)
                return block.withProductivityTag(tag)
            }
        } catch {
            // LLM failed — fall back to heuristic, don't crash
            return blocks.map { applyHeuristicTag($0) }
        }
    }

    // MARK: - Prompt Building

    private func buildNarrativePrompt(
        entries: [TimeEntry],
        sleepMinutes: Int,
        steps: Int,
        workoutMinutes: Int,
        meetingMinutes: Int,
        awTopApps: [String],
        dailyScore: Int?
    ) -> String {
        // Summarise time entries by category
        var categoryTotals: [String: Int] = [:]
        for entry in entries {
            let name = entry.category?.name ?? entry.sourceRaw
            categoryTotals[name, default: 0] += entry.durationMinutes
        }
        let categoryLines = categoryTotals
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map { "  - \($0.key): \($0.value)m" }
            .joined(separator: "\n")

        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .none)
        let sleepHours = String(format: "%.1f", Double(sleepMinutes) / 60.0)
        let appStr = awTopApps.isEmpty ? "no desktop data" : awTopApps.prefix(5).joined(separator: ", ")
        let scoreStr = dailyScore.map { "Day score: \($0)/100" } ?? ""

        return """
        You are a personal time coach. Analyse this day and respond in exactly two parts.

        Date: \(dateStr)
        Sleep last night: \(sleepHours)h
        Steps: \(steps)
        Workout: \(workoutMinutes)m
        Meetings: \(meetingMinutes)m
        Desktop apps used: \(appStr)
        \(scoreStr)
        Time breakdown:
        \(categoryLines.isEmpty ? "  (no entries)" : categoryLines)

        Reply in this exact format (no extra text):
        SUMMARY: <3–4 sentences explaining the shape of this day — what I was focused on, what the data suggests about my energy and priorities. Be specific, not generic.>
        SUGGESTION: <One concrete, actionable thing I could do differently tomorrow. One sentence.>
        """
    }

    private func buildTaggingPrompt(blocks: [AWActivityBlock]) -> String {
        // Collect a concise list of events per block (up to 5 window titles)
        let blockLines = blocks.map { block -> String in
            let sampleTitles = block.events
                .prefix(5)
                .map { $0.windowTitle.prefix(80) }
                .filter { !$0.isEmpty }
                .map { "\"\($0)\"" }
                .joined(separator: ", ")
            return "  {\"id\":\"\(block.id.uuidString)\",\"app\":\"\(block.topApp)\",\"minutes\":\(block.durationMinutes),\"titles\":[\(sampleTitles)]}"
        }.joined(separator: ",\n")

        return """
        Classify each desktop activity block as productive, distracted, or break.
        - productive: focused goal-oriented work (coding, writing, design, reading docs)
        - distracted: aimless browsing, social media, random YouTube/Reddit
        - break: intentional rest (music, short entertainment, stepping away)

        Blocks:
        [
        \(blockLines)
        ]

        Reply ONLY with valid JSON — no explanation, no markdown:
        [{"id":"<uuid>","tag":"productive|distracted|break"}, ...]
        """
    }

    // MARK: - Response Parsing

    private func parseNarrativeResponse(_ raw: String) -> DailyNarrativeResult {
        var narrative  = ""
        var suggestion = ""

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SUMMARY:") {
                narrative = String(trimmed.dropFirst("SUMMARY:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("SUGGESTION:") {
                suggestion = String(trimmed.dropFirst("SUGGESTION:".count)).trimmingCharacters(in: .whitespaces)
            }
        }

        // Graceful fallback: if parsing fails, use the whole response
        if narrative.isEmpty {
            narrative = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return DailyNarrativeResult(narrative: narrative, suggestion: suggestion)
    }

    private func parseTaggingResponse(_ raw: String) -> [String: ProductivityTag] {
        // Extract just the JSON array (model may wrap it in markdown code fences)
        var jsonStr = raw
        if let start = raw.range(of: "["), let end = raw.range(of: "]", options: .backwards) {
            jsonStr = String(raw[start.lowerBound...end.upperBound])
        }

        guard let data = jsonStr.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return [:]
        }

        var result: [String: ProductivityTag] = [:]
        for item in array {
            guard let id = item["id"], let tagStr = item["tag"] else { continue }
            result[id] = ProductivityTag(rawValue: tagStr) ?? .unknown
        }
        return result
    }

    // MARK: - Heuristic Fallback

    private func applyHeuristicTag(_ block: AWActivityBlock) -> AWActivityBlock {
        block.withProductivityTag(heuristicTag(for: block))
    }

    private func heuristicTag(for block: AWActivityBlock) -> ProductivityTag {
        // Mirror the existing Deep Work / Desk Time logic as a fallback
        block.category == "Deep Work" ? .productive : .unknown
    }
}

// MARK: - AWActivityBlock extension

extension AWActivityBlock {
    /// Return a copy of this block with a new productivity tag.
    func withProductivityTag(_ tag: ProductivityTag) -> AWActivityBlock {
        AWActivityBlock(
            start: start,
            end: end,
            category: category,
            topApp: topApp,
            events: events,
            productivityTag: tag
        )
    }
}
