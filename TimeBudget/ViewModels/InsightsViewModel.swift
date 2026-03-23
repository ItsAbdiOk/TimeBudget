import Foundation
import SwiftData

@MainActor
@Observable
final class InsightsViewModel {
    var correlations: [Correlation] = []
    var fragmentationScore: Double = 1.0
    var fragmentationLabel: String = "Focused"
    var isLoading = true

    // MARK: - AI Narrative State
    var dailyNarrative: String?
    var dailySuggestion: String?
    var isGeneratingNarrative = false
    var narrativeError: String?

    private let correlationEngine = CorrelationEngine.shared

    func loadInsights(context: ModelContext) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        // Fetch snapshots for correlation analysis (last 90 days)
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let snapshotDescriptor = FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate<HealthSnapshot> { snapshot in
                snapshot.date >= ninetyDaysAgo
            },
            sortBy: [SortDescriptor(\.date)]
        )
        let snapshots = (try? context.fetch(snapshotDescriptor)) ?? []

        // Compute correlations
        correlations = correlationEngine.computeCorrelations(snapshots: snapshots)

        // Compute today's fragmentation
        let today = Date()
        let startOfDay = Calendar.current.startOfDay(for: today)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let entryDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startDate >= startOfDay && entry.startDate < endOfDay
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let todayEntries = (try? context.fetch(entryDescriptor)) ?? []

        fragmentationScore = correlationEngine.fragmentationScore(entries: todayEntries)
        fragmentationLabel = fragmentationText(fragmentationScore)

        // Load cached AI narrative if available and fresh
        await loadCachedNarrative(context: context)
    }

    // MARK: - AI Narrative

    func generateAIInsights(context: ModelContext) async {
        guard LLMServiceFactory.isConfigured else {
            narrativeError = "AI Analysis not configured. Go to Settings → AI Analysis."
            return
        }
        guard !isGeneratingNarrative else { return }

        isGeneratingNarrative = true
        narrativeError = nil

        // Fetch today's entries
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let entryDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startDate >= startOfDay && entry.startDate < endOfDay
            }
        )
        let todayEntries = (try? context.fetch(entryDescriptor)) ?? []

        // Fetch today's health snapshot (most recent)
        let snapshotDescriptor = FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate<HealthSnapshot> { s in s.date >= startOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let snapshot = (try? context.fetch(snapshotDescriptor))?.first

        // Attempt to get ActivityWatch top apps
        let awTopApps: [String]
        if let blocks = try? await ActivityWatchService.shared.fetchTodayBlocks() {
            var appDurations: [String: Int] = [:]
            for block in blocks {
                appDurations[block.topApp, default: 0] += block.durationMinutes
            }
            awTopApps = appDurations.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        } else {
            awTopApps = []
        }

        do {
            let result = try await LLMAnalysisService.shared.generateDailyNarrative(
                entries: todayEntries,
                sleepMinutes: snapshot?.sleepMinutes ?? 0,
                steps: snapshot?.steps ?? 0,
                workoutMinutes: snapshot?.workoutMinutes ?? 0,
                meetingMinutes: todayEntries
                    .filter { $0.sourceRaw == DataSource.calendar.rawValue }
                    .reduce(0) { $0 + $1.durationMinutes },
                awTopApps: awTopApps,
                dailyScore: nil
            )

            dailyNarrative  = result.narrative
            dailySuggestion = result.suggestion

            // Persist to SwiftData cache
            let providerRaw = UserDefaults.standard.string(forKey: "llm_provider") ?? "ollama"
            let analysis = DailyAnalysis(
                date: Date(),
                narrative: result.narrative,
                suggestion: result.suggestion,
                llmProvider: providerRaw
            )

            // Remove any existing analysis for today
            let existing = (try? context.fetch(FetchDescriptor<DailyAnalysis>(
                predicate: #Predicate<DailyAnalysis> { $0.date >= startOfDay }
            ))) ?? []
            existing.forEach { context.delete($0) }

            context.insert(analysis)
            try? context.save()

        } catch {
            narrativeError = error.localizedDescription
        }

        isGeneratingNarrative = false
    }

    // MARK: - Cache Loading

    private func loadCachedNarrative(context: ModelContext) async {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailyAnalysis>(
            predicate: #Predicate<DailyAnalysis> { $0.date >= startOfDay },
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        guard let cached = (try? context.fetch(descriptor))?.first else { return }

        if !cached.isStale {
            dailyNarrative  = cached.narrative
            dailySuggestion = cached.suggestion
        }
        // If stale, leave nil so the user sees the refresh prompt
    }

    // MARK: - Helpers

    private func fragmentationText(_ score: Double) -> String {
        switch score {
        case 0.8...: return "Very Focused"
        case 0.6..<0.8: return "Focused"
        case 0.4..<0.6: return "Moderate"
        case 0.2..<0.4: return "Fragmented"
        default: return "Very Fragmented"
        }
    }
}
