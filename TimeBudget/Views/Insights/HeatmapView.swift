import SwiftUI

struct HeatmapView: View {
    @State private var dailyData: [Date: Int] = [:]
    @State private var isLoading = true
    @State private var hasData = false

    private let healthKit = HealthKitService.shared

    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading activity data...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                ContributionCalendarView(
                    data: dailyData,
                    accentColor: .blue
                )
            }
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true

        let calendar = Calendar.current
        let sixteenWeeksAgo = calendar.date(byAdding: .day, value: -91, to: Date())!
        let now = Date()

        let workouts = (try? await healthKit.fetchWorkoutsInRange(from: sixteenWeeksAgo, to: now)) ?? []
        let sleepSamples = (try? await healthKit.fetchSleepSamplesInRange(from: sixteenWeeksAgo, to: now)) ?? []

        guard !workouts.isEmpty || !sleepSamples.isEmpty else {
            isLoading = false
            return
        }

        var daily: [Date: Int] = [:]

        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            daily[day, default: 0] += workout.durationMinutes
        }

        for sample in sleepSamples where sample.stage != .awake {
            let day = calendar.startOfDay(for: sample.startDate)
            daily[day, default: 0] += sample.durationMinutes
        }

        dailyData = daily
        hasData = true
        isLoading = false
    }
}
