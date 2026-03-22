import Foundation
import SwiftData

@MainActor
@Observable
final class InsightsViewModel {
    var correlations: [Correlation] = []
    var fragmentationScore: Double = 1.0
    var fragmentationLabel: String = "Focused"
    var isLoading = true

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
    }

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

