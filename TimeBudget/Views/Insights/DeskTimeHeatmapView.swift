import SwiftUI

struct DeskTimeHeatmapView: View {
    @State private var dailyData: [Date: Int] = [:]
    @State private var totalMinutes: Int = 0
    @State private var totalBlocks: Int = 0
    @State private var topApp: String?
    @State private var isLoading = true
    @State private var hasData = false

    private let service = ActivityWatchService.shared
    private let accentColor = Color(hex: "#8B5CF6")

    var body: some View {
        VStack(spacing: 14) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading desktop data...")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if !hasData {
                EmptyStateView(
                    icon: "desktopcomputer",
                    title: "No desktop data yet",
                    subtitle: "Your ActivityWatch data will appear here"
                )
            } else {
                // Stats row
                HStack(spacing: 0) {
                    StatBadge(
                        value: formatMinutes(totalMinutes),
                        label: "desk time",
                        icon: "desktopcomputer",
                        color: accentColor
                    )
                    StatBadge(
                        value: "\(totalBlocks)",
                        label: "sessions",
                        icon: "square.stack",
                        color: accentColor
                    )
                    if let top = topApp {
                        VStack(spacing: 4) {
                            Text(top)
                                .font(.system(.caption).weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            Text("top app")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                ContributionCalendarView(
                    data: dailyData,
                    accentColor: accentColor
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
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -84, to: now)!

        let blocks: [AWActivityBlock]
        do {
            blocks = try await service.fetchBlocks(from: start, to: now)
        } catch {
            print("[DeskTimeHeatmap] Failed to load: \(error.localizedDescription)")
            isLoading = false
            return
        }

        guard !blocks.isEmpty else {
            isLoading = false
            return
        }

        var daily: [Date: Int] = [:]
        var appDurations: [String: TimeInterval] = [:]
        var totalMins = 0

        for block in blocks {
            let day = calendar.startOfDay(for: block.start)
            let mins = block.durationMinutes
            daily[day, default: 0] += mins
            totalMins += mins
            for event in block.events {
                appDurations[event.appName, default: 0] += event.duration
            }
        }

        dailyData = daily
        totalMinutes = totalMins
        totalBlocks = blocks.count
        topApp = appDurations.max(by: { $0.value < $1.value })?.key
        hasData = true
        isLoading = false
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3).weight(.semibold).monospacedDigit())
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}
