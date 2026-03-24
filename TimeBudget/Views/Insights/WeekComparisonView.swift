import SwiftUI
import Charts

struct WeekComparisonView: View {
    @State private var thisWeekData: [CategoryMinutes] = []
    @State private var lastWeekData: [CategoryMinutes] = []
    @State private var isLoading = true

    private let healthKit = HealthKitService.shared
    private let aniList = AniListService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading comparison...")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if thisWeekData.isEmpty && lastWeekData.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    title: "Not enough data yet",
                    subtitle: "Check back after a few days of tracking"
                )
            } else {
                Chart {
                    ForEach(thisWeekData, id: \.category) { item in
                        BarMark(
                            x: .value("Category", item.category),
                            y: .value("Hours", Double(item.minutes) / 60.0)
                        )
                        .foregroundStyle(by: .value("Week", "This Week"))
                        .position(by: .value("Week", "This Week"))
                        .cornerRadius(4)
                    }

                    ForEach(lastWeekData, id: \.category) { item in
                        BarMark(
                            x: .value("Category", item.category),
                            y: .value("Hours", Double(item.minutes) / 60.0)
                        )
                        .foregroundStyle(by: .value("Week", "Last Week"))
                        .position(by: .value("Week", "Last Week"))
                        .cornerRadius(4)
                    }
                }
                .chartForegroundStyleScale([
                    "This Week": Color(.systemGreen),
                    "Last Week": Color(.systemGreen).opacity(0.25),
                ])
                .chartYAxisLabel("Hours")
                .frame(height: 200)
            }
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true

        let calendar = Calendar.current
        let today = Date()
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!

        async let thisWeek = fetchCategoryMinutes(from: thisWeekStart, to: today)
        async let lastWeek = fetchCategoryMinutes(from: lastWeekStart, to: thisWeekStart)

        thisWeekData = await thisWeek
        lastWeekData = await lastWeek
        isLoading = false
    }

    private func fetchCategoryMinutes(from start: Date, to end: Date) async -> [CategoryMinutes] {
        var categories: [String: Int] = [:]

        // Sleep from HealthKit
        let sleepSamples = (try? await healthKit.fetchSleepSamplesInRange(from: start, to: end)) ?? []
        let sleepMinutes = sleepSamples
            .filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.durationMinutes }
        if sleepMinutes > 0 {
            categories["Sleep"] = sleepMinutes
        }

        // Workouts from HealthKit
        let workouts = (try? await healthKit.fetchWorkoutsInRange(from: start, to: end)) ?? []
        let exerciseMinutes = workouts.reduce(0) { $0 + $1.durationMinutes }
        if exerciseMinutes > 0 {
            categories["Exercise"] = exerciseMinutes
        }

        // Reading from AniList
        let readings = (try? await aniList.fetchReadingActivity(from: start, to: end)) ?? []
        let readingMinutes = readings.reduce(0) { $0 + $1.chaptersRead * aniList.minutesPerChapter }
        if readingMinutes > 0 {
            categories["Reading"] = readingMinutes
        }

        // Steps as "Walking" estimate (rough: 100 steps/min walking)
        let stepsData = (try? await healthKit.fetchStepsInRange(from: start, to: end)) ?? []
        let totalSteps = stepsData.reduce(0) { $0 + $1.steps }
        let walkingMinutes = totalSteps / 100
        if walkingMinutes > 0 {
            categories["Walking"] = walkingMinutes
        }

        return categories.map { CategoryMinutes(category: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
            .prefix(6)
            .map { $0 }
    }
}

struct CategoryMinutes {
    let category: String
    let minutes: Int
}
