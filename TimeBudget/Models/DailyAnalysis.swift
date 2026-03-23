import Foundation
import SwiftData

/// Cached AI-generated narrative for a single day.
/// Re-generated when stale (> 6 hours old) or on user request.
@Model
final class DailyAnalysis {
    var date: Date           // start of day (midnight)
    var narrative: String    // LLM-generated day summary
    var suggestion: String   // LLM-generated single actionable suggestion
    var generatedAt: Date    // when the LLM was last called
    var llmProvider: String  // "ollama" or "foundation"

    init(date: Date, narrative: String, suggestion: String, llmProvider: String) {
        self.date        = Calendar.current.startOfDay(for: date)
        self.narrative   = narrative
        self.suggestion  = suggestion
        self.generatedAt = Date()
        self.llmProvider = llmProvider
    }

    /// True if the analysis is stale and should be regenerated.
    var isStale: Bool {
        Date().timeIntervalSince(generatedAt) > 6 * 3600  // 6 hours
    }
}
