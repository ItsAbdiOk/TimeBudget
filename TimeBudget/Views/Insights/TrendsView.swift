import SwiftUI
import Charts
import SwiftData

struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trendData: [TrendPoint] = []
    @State private var isLoading = true

    private let healthKit = HealthKitService.shared
    private let aniList = AniListService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading trends...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if trendData.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No trends yet",
                    subtitle: "Trends appear after a few days of data"
                )
            } else {
                Chart(trendData, id: \.id) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(by: .value("Metric", point.metric))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(by: .value("Metric", point.metric))
                    .opacity(0.08)
                }
                .chartForegroundStyleScale([
                    "Sleep (hrs)": Color.indigo,
                    "Steps (k)": Color.green,
                    "Exercise (hrs)": Color.orange,
                    "Reading (hrs)": Color(hex: "#AC8E68"),
                ])
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
            }
        }
        .task { await loadTrends() }
    }

    private func loadTrends() async {
        isLoading = true

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let now = Date()

        // Ensure HealthSnapshots exist for the past 30 days by backfilling from HealthKit
        await backfillSnapshots(from: thirtyDaysAgo, to: now)

        // Fetch snapshots
        let descriptor = FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate<HealthSnapshot> { snapshot in
                snapshot.date >= thirtyDaysAgo
            },
            sortBy: [SortDescriptor(\.date)]
        )
        let snapshots = (try? modelContext.fetch(descriptor)) ?? []

        // Fetch AniList reading data for the same 30-day period
        let readingActivities = (try? await aniList.fetchReadingActivity(from: thirtyDaysAgo, to: now)) ?? []

        // Group reading activities by day
        var readingByDay: [String: Int] = [:]
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        for activity in readingActivities {
            let key = dayFormatter.string(from: activity.createdAt)
            readingByDay[key, default: 0] += activity.chaptersRead * aniList.minutesPerChapter
        }

        // Build trend points
        var points: [TrendPoint] = []
        for snapshot in snapshots {
            points.append(TrendPoint(
                date: snapshot.date,
                metric: "Sleep (hrs)",
                value: Double(snapshot.sleepMinutes) / 60.0
            ))
            points.append(TrendPoint(
                date: snapshot.date,
                metric: "Steps (k)",
                value: Double(snapshot.steps) / 1000.0
            ))
            points.append(TrendPoint(
                date: snapshot.date,
                metric: "Exercise (hrs)",
                value: Double(snapshot.workoutMinutes) / 60.0
            ))

            let dayKey = dayFormatter.string(from: snapshot.date)
            let readingMins = readingByDay[dayKey] ?? 0
            points.append(TrendPoint(
                date: snapshot.date,
                metric: "Reading (hrs)",
                value: Double(readingMins) / 60.0
            ))
        }

        trendData = points
        isLoading = false
    }

    private func backfillSnapshots(from start: Date, to end: Date) async {
        // Check which days already have snapshots
        let descriptor = FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate<HealthSnapshot> { snapshot in
                snapshot.date >= start
            }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingDates = Set(existing.map { Calendar.current.startOfDay(for: $0.date) })

        // Find missing days
        var missingDates: [Date] = []
        var current = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)
        while current <= endDay {
            if !existingDates.contains(current) {
                missingDates.append(current)
            }
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        }

        guard !missingDates.isEmpty else { return }

        // Backfill missing days from HealthKit
        for date in missingDates {
            let steps = (try? await healthKit.fetchSteps(for: date)) ?? 0
            let sleepMinutes = (try? await healthKit.fetchTotalSleepMinutes(for: date)) ?? 0
            let workouts = (try? await healthKit.fetchWorkouts(for: date)) ?? []
            let workoutMinutes = workouts.reduce(0) { $0 + $1.durationMinutes }
            let calories = (try? await healthKit.fetchActiveCalories(for: date)) ?? 0

            let snapshot = HealthSnapshot(
                date: date,
                steps: steps,
                activeCalories: calories,
                sleepMinutes: sleepMinutes,
                workoutMinutes: workoutMinutes,
                workoutCount: workouts.count
            )
            modelContext.insert(snapshot)
        }

        try? modelContext.save()
    }
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let metric: String
    let value: Double
}
