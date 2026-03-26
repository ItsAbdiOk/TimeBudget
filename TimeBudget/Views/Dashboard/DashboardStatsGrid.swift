import SwiftUI

// MARK: - Mini Stats Row

struct DashboardStatsGrid: View {
    let steps: Int
    let sleepMinutes: Int
    let workouts: [WorkoutSample]

    private var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        LazyVGrid(columns: columns, spacing: 10) {
            MiniStatCard(label: "STEPS", value: formattedSteps, unit: nil, delta: "\u{2191} 8%", deltaPositive: true)
            MiniStatCard(label: "SLEEP", value: sleepValue, unit: sleepUnit, delta: "\u{2193} 10m", deltaPositive: false)
            MiniStatCard(label: "EXERCISE", value: exerciseValue, unit: exerciseUnit, delta: "\u{2191} 12%", deltaPositive: true)
        }
    }

    private var sleepValue: String {
        let hours = sleepMinutes / 60
        return "\(hours)"
    }

    private var sleepUnit: String {
        let mins = sleepMinutes % 60
        return "h \(mins)m"
    }

    private var exerciseValue: String {
        let totalMinutes = workouts.reduce(0) { $0 + $1.durationMinutes }
        return "\(totalMinutes)"
    }

    private var exerciseUnit: String {
        return "min"
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
    let label: String
    let value: String
    let unit: String?
    let delta: String
    let deltaPositive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color(.tertiaryLabel))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text(delta)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(deltaPositive ? Color(.systemGreen) : Color(.systemRed))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

#Preview("Stats Grid") {
    DashboardStatsGrid(steps: 8432, sleepMinutes: 450, workouts: [])
        .padding()
}

#Preview("Mini Stat Card") {
    MiniStatCard(label: "STEPS", value: "8,432", unit: nil, delta: "\u{2191} 8%", deltaPositive: true)
        .frame(width: 120)
        .padding()
}
