import SwiftUI
import Charts

struct ActivityDetailView: View {
    @State private var weeklyData: [(week: String, minutes: Int)] = []
    @State private var workoutBreakdown: [(type: String, minutes: Int)] = []
    @State private var dailySteps: [(date: Date, steps: Int)] = []
    @State private var totalWorkouts: Int = 0
    @State private var avgDailyMinutes: Int = 0
    @State private var currentStreak: Int = 0
    @State private var isLoading = true

    private let healthKit = HealthKitService.shared

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else {
                        // Summary stats
                        HStack(spacing: 0) {
                            StatItem(value: "\(totalWorkouts)", label: "workouts", color: .green)
                            StatItem(value: "\(avgDailyMinutes)m", label: "avg/day", color: .green)
                            StatItem(value: "\(currentStreak)", label: "day streak", color: .green)
                        }
                        .card()
                        .padding(.horizontal, 16)

                        // Weekly trend
                        if !weeklyData.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("WEEKLY EXERCISE")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)

                                Chart(weeklyData, id: \.week) { item in
                                    BarMark(
                                        x: .value("Week", item.week),
                                        y: .value("Hours", Double(item.minutes) / 60.0)
                                    )
                                    .foregroundStyle(Color.green.gradient)
                                    .cornerRadius(4)
                                }
                                .chartYAxisLabel("Hours")
                                .frame(height: 200)
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Workout type breakdown
                        if !workoutBreakdown.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("WORKOUT TYPES")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)

                                ForEach(workoutBreakdown, id: \.type) { item in
                                    HStack {
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 8, height: 8)
                                        Text(item.type)
                                            .font(.system(.subheadline, design: .rounded))
                                        Spacer()
                                        Text(formatMinutes(item.minutes))
                                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Daily steps chart
                        if !dailySteps.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DAILY STEPS (30 DAYS)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)

                                Chart(dailySteps, id: \.date) { item in
                                    BarMark(
                                        x: .value("Date", item.date, unit: .day),
                                        y: .value("Steps", item.steps)
                                    )
                                    .foregroundStyle(Color.blue.gradient)
                                    .cornerRadius(2)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                    }
                                }
                                .frame(height: 160)
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Heatmap
                        HeatmapView()
                            .card()
                            .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Activity")
        .task { await loadData() }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func loadData() async {
        isLoading = true
        let calendar = Calendar.current
        let now = Date()
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now)!
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!

        async let workoutsTask = (try? await healthKit.fetchWorkoutsInRange(from: ninetyDaysAgo, to: now)) ?? []
        async let stepsTask = (try? await healthKit.fetchStepsInRange(from: thirtyDaysAgo, to: now)) ?? []

        let workouts = await workoutsTask
        let steps = await stepsTask

        // Total workouts
        totalWorkouts = workouts.count

        // Weekly aggregation (last 12 weeks)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        var weekBuckets: [(label: String, minutes: Int)] = []
        for i in (0..<12).reversed() {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: calendar.startOfDay(for: now))!
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
            let weekMinutes = workouts
                .filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
                .reduce(0) { $0 + $1.durationMinutes }
            weekBuckets.append((label: formatter.string(from: weekStart), minutes: weekMinutes))
        }
        weeklyData = weekBuckets.map { (week: $0.label, minutes: $0.minutes) }

        // Avg daily exercise (last 30 days)
        let recentWorkouts = workouts.filter { $0.startDate >= thirtyDaysAgo }
        let recentTotalMins = recentWorkouts.reduce(0) { $0 + $1.durationMinutes }
        avgDailyMinutes = recentTotalMins / 30

        // Workout type breakdown
        var byType: [String: Int] = [:]
        for w in workouts {
            byType[w.name, default: 0] += w.durationMinutes
        }
        workoutBreakdown = byType.map { (type: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }

        // Current streak (days with any workout)
        var streak = 0
        var checkDate = calendar.startOfDay(for: now)
        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.startDate) })
        while workoutDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        currentStreak = streak

        // Daily steps
        dailySteps = steps.map { (date: $0.date, steps: $0.steps) }
            .sorted { $0.date < $1.date }

        isLoading = false
    }
}

private struct StatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
