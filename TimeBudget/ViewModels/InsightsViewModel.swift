import Foundation
import SwiftData
import SwiftUI

// MARK: - Trend Metric Model

struct TrendMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let unit: String
    let deltaText: String
    let deltaPositive: Bool
    let sparklinePoints: [CGFloat]
    let accentColor: Color
}

// MARK: - ViewModel

@MainActor
@Observable
final class InsightsViewModel {
    var correlations: [Correlation] = []
    var trendMetrics: [TrendMetric] = []
    var fragmentationScore: Double = 1.0
    var fragmentationLabel: String = "Focused"
    var isLoading = false

    private let correlationEngine = CorrelationEngine.shared

    func loadInsights(context: ModelContext) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current

        // Fetch snapshots for correlation analysis (last 90 days)
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: Date())!
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
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let entryDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startDate >= startOfDay && entry.startDate < endOfDay
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let todayEntries = (try? context.fetch(entryDescriptor)) ?? []

        fragmentationScore = correlationEngine.fragmentationScore(entries: todayEntries)
        fragmentationLabel = fragmentationText(fragmentationScore)

        // Compute trend metrics
        loadTrendMetrics(snapshots: snapshots)
    }

    // MARK: - Trend Metrics

    private func loadTrendMetrics(snapshots: [HealthSnapshot]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Split into current 30 days and previous 30 days
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: today)!

        let current = snapshots.filter { $0.date >= thirtyDaysAgo }
        let previous = snapshots.filter { $0.date >= sixtyDaysAgo && $0.date < thirtyDaysAgo }

        var metrics: [TrendMetric] = []

        // 1. Avg Sleep
        if !current.isEmpty {
            let avgSleep = current.reduce(0) { $0 + $1.sleepMinutes } / current.count
            let prevAvgSleep = previous.isEmpty ? avgSleep : previous.reduce(0) { $0 + $1.sleepMinutes } / previous.count
            let deltaMin = avgSleep - prevAvgSleep
            let hours = avgSleep / 60
            let mins = avgSleep % 60

            metrics.append(TrendMetric(
                label: "AVG SLEEP",
                value: "\(hours)",
                unit: "h \(String(format: "%02d", mins))m",
                deltaText: deltaMin >= 0 ? "↑ \(abs(deltaMin))m vs last month" : "↓ \(abs(deltaMin))m vs last month",
                deltaPositive: deltaMin >= 0,
                sparklinePoints: buildSparkline(current.map { CGFloat($0.sleepMinutes) }),
                accentColor: Color(.systemTeal)
            ))
        }

        // 2. Avg Steps
        if !current.isEmpty {
            let avgSteps = current.reduce(0) { $0 + $1.steps } / current.count
            let prevAvgSteps = previous.isEmpty ? avgSteps : previous.reduce(0) { $0 + $1.steps } / previous.count
            let delta = avgSteps - prevAvgSteps
            let displayVal: String
            let displayUnit: String
            if avgSteps >= 1000 {
                let k = Double(avgSteps) / 1000.0
                displayVal = String(format: "%.1f", k)
                displayUnit = "k"
            } else {
                displayVal = "\(avgSteps)"
                displayUnit = ""
            }

            metrics.append(TrendMetric(
                label: "AVG STEPS",
                value: displayVal,
                unit: displayUnit,
                deltaText: delta >= 0 ? "↑ \(abs(delta)) vs last month" : "↓ \(abs(delta)) vs last month",
                deltaPositive: delta >= 0,
                sparklinePoints: buildSparkline(current.map { CGFloat($0.steps) }),
                accentColor: Color(.systemGreen)
            ))
        }

        // 3. Exercise
        if !current.isEmpty {
            let avgExercise = current.reduce(0) { $0 + $1.workoutMinutes } / current.count
            let prevAvgExercise = previous.isEmpty ? avgExercise : previous.reduce(0) { $0 + $1.workoutMinutes } / previous.count
            let delta = avgExercise - prevAvgExercise
            let hours = avgExercise / 60
            let mins = avgExercise % 60

            let val: String
            let unit: String
            if hours > 0 {
                val = "\(hours)"
                unit = "h \(mins)m"
            } else {
                val = "\(mins)"
                unit = "min"
            }

            metrics.append(TrendMetric(
                label: "EXERCISE",
                value: val,
                unit: unit,
                deltaText: delta >= 0 ? "↑ \(abs(delta))m vs last month" : "↓ \(abs(delta))m vs last month",
                deltaPositive: delta >= 0,
                sparklinePoints: buildSparkline(current.map { CGFloat($0.workoutMinutes) }),
                accentColor: Color(.systemOrange)
            ))
        }

        // 4. Active Calories
        if !current.isEmpty {
            let avgCal = Int(current.reduce(0.0) { $0 + $1.activeCalories } / Double(current.count))
            let prevAvgCal = previous.isEmpty ? avgCal : Int(previous.reduce(0.0) { $0 + $1.activeCalories } / Double(previous.count))
            let delta = avgCal - prevAvgCal

            metrics.append(TrendMetric(
                label: "AVG CALORIES",
                value: "\(avgCal)",
                unit: "kcal",
                deltaText: delta >= 0 ? "↑ \(abs(delta)) vs last month" : "↓ \(abs(delta)) vs last month",
                deltaPositive: delta >= 0,
                sparklinePoints: buildSparkline(current.map { CGFloat($0.activeCalories) }),
                accentColor: Color(.systemPurple)
            ))
        }

        trendMetrics = metrics
    }

    private func buildSparkline(_ values: [CGFloat]) -> [CGFloat] {
        guard values.count >= 2 else { return [0.5, 0.5] }

        // Group into ~8 buckets
        let bucketCount = min(8, values.count)
        let bucketSize = max(1, values.count / bucketCount)
        var buckets: [CGFloat] = []

        for i in 0..<bucketCount {
            let start = i * bucketSize
            let end = min(start + bucketSize, values.count)
            let slice = values[start..<end]
            let avg = slice.reduce(0, +) / CGFloat(slice.count)
            buckets.append(avg)
        }

        // Normalize to 0...1
        let minVal = buckets.min() ?? 0
        let maxVal = buckets.max() ?? 1
        let range = maxVal - minVal
        if range == 0 { return buckets.map { _ in CGFloat(0.5) } }

        return buckets.map { ($0 - minVal) / range }
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
