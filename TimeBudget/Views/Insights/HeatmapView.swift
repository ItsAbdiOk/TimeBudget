import SwiftUI

struct HeatmapView: View {
    @State private var dailyData: [Date: Int] = [:]
    @State private var totalActiveMinutes: Int = 0
    @State private var activeDays: Int = 0
    @State private var bestDay: Int = 0
    @State private var isLoading = true
    @State private var hasData = false

    private let healthKit = HealthKitService.shared

    var body: some View {
        VStack(spacing: 14) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading activity data...")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if !hasData {
                EmptyStateView(
                    icon: "figure.walk",
                    title: "No activity data yet",
                    subtitle: "Your workout and activity data will appear here"
                )
            } else {
                // Stats row
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("\(activeDays)")
                            .font(.system(.title3).weight(.semibold).monospacedDigit())
                        Text("active days")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text(formatMinutes(totalActiveMinutes))
                            .font(.system(.title3).weight(.semibold).monospacedDigit())
                        Text("total exercise")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text(formatMinutes(bestDay))
                            .font(.system(.title3).weight(.semibold).monospacedDigit())
                        Text("best day")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity)
                }

                ContributionCalendarView(
                    data: dailyData,
                    accentColor: Color(.systemGreen),
                    weeks: 15
                )
            }
        }
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
        let sixteenWeeksAgo = calendar.date(byAdding: .day, value: -105, to: Date())!
        let now = Date()

        async let workoutsTask = (try? await healthKit.fetchWorkoutsInRange(from: sixteenWeeksAgo, to: now)) ?? []
        async let stepsTask = (try? await healthKit.fetchStepsInRange(from: sixteenWeeksAgo, to: now)) ?? []

        let workouts = await workoutsTask
        let steps = await stepsTask

        guard !workouts.isEmpty || !steps.isEmpty else {
            isLoading = false
            return
        }

        // Use workout minutes as the primary heatmap metric — clearly shows active vs lazy days
        var daily: [Date: Int] = [:]
        var totalMins = 0

        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            daily[day, default: 0] += workout.durationMinutes
            totalMins += workout.durationMinutes
        }

        // For days with no workout, add a small bump if steps are significant (10k+ = light activity)
        for entry in steps {
            let day = calendar.startOfDay(for: entry.date)
            if daily[day] == nil && entry.steps >= 5000 {
                // Scale steps into approximate active minutes (10k steps ≈ 30 min walk equivalent)
                let activeMinutes = min(entry.steps / 333, 45)
                daily[day] = activeMinutes
            }
        }

        dailyData = daily
        totalActiveMinutes = totalMins
        activeDays = daily.values.filter { $0 > 0 }.count
        bestDay = daily.values.max() ?? 0
        hasData = true
        isLoading = false
    }
}
