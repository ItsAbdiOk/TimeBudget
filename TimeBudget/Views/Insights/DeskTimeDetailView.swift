import SwiftUI
import Charts

struct DeskTimeDetailView: View {
    @State private var blocks: [AWActivityBlock] = []
    @State private var appStats: [(app: String, minutes: Int, category: String)] = []
    @State private var weeklyData: [(week: String, minutes: Int)] = []
    @State private var dailyData: [Date: Int] = [:]
    @State private var totalMinutes: Int = 0
    @State private var deepWorkMinutes: Int = 0
    @State private var avgPerDay: Int = 0
    @State private var longestSession: Int = 0
    @State private var isLoading = true

    private let service = ActivityWatchService.shared
    private let accentColor = Color(hex: "#8B5CF6")

    private let deepWorkApps: Set<String> = [
        "Xcode", "Visual Studio Code", "Code", "Terminal", "iTerm2",
        "IntelliJ IDEA", "PyCharm", "WebStorm", "Sublime Text", "Vim",
        "Neovim", "Cursor", "Android Studio", "CLion", "DataGrip",
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else if blocks.isEmpty {
                        EmptyStateView(
                            icon: "desktopcomputer",
                            title: "No desktop data",
                            subtitle: "Make sure ActivityWatch is running on your desktop"
                        )
                    } else {
                        // Summary stats
                        HStack(spacing: 0) {
                            StatBadge(value: formatMinutes(totalMinutes), label: "total")
                            StatBadge(value: formatMinutes(deepWorkMinutes), label: "deep work")
                            StatBadge(value: "\(avgPerDay)m", label: "avg/day")
                            StatBadge(value: formatMinutes(longestSession), label: "longest")
                        }
                        .card()
                        .padding(.horizontal, 16)

                        // Deep Work vs Desk Time ratio
                        if totalMinutes > 0 {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DEEP WORK RATIO")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)

                                let ratio = Double(deepWorkMinutes) / Double(totalMinutes)

                                HStack(spacing: 16) {
                                    CircularProgress(
                                        progress: ratio,
                                        lineWidth: 8,
                                        color: accentColor
                                    )
                                    .frame(width: 64, height: 64)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("\(Int(ratio * 100))% productive")
                                            .font(.system(.headline, design: .rounded))

                                        HStack(spacing: 12) {
                                            HStack(spacing: 4) {
                                                Circle().fill(accentColor).frame(width: 8, height: 8)
                                                Text("Deep Work")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            HStack(spacing: 4) {
                                                Circle().fill(Color(.tertiarySystemFill)).frame(width: 8, height: 8)
                                                Text("Other")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Weekly trend
                        if !weeklyData.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("WEEKLY DESK TIME")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)

                                Chart(weeklyData, id: \.week) { item in
                                    BarMark(
                                        x: .value("Week", item.week),
                                        y: .value("Hours", Double(item.minutes) / 60.0)
                                    )
                                    .foregroundStyle(accentColor.gradient)
                                    .cornerRadius(4)
                                }
                                .chartYAxisLabel("Hours")
                                .frame(height: 200)
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // App breakdown
                        if !appStats.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("TOP APPS")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)

                                ForEach(appStats.prefix(12), id: \.app) { app in
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(deepWorkApps.contains(app.app) ? accentColor : Color(.tertiarySystemFill))
                                            .frame(width: 8, height: 8)

                                        Text(app.app)
                                            .font(.system(.subheadline, design: .rounded))
                                            .lineLimit(1)

                                        Spacer()

                                        Text(app.category)
                                            .font(.system(.caption2, design: .rounded).weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color(.tertiarySystemFill))
                                            .clipShape(Capsule())

                                        Text(formatMinutes(app.minutes))
                                            .font(.system(.caption, design: .rounded).weight(.medium))
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 55, alignment: .trailing)
                                    }
                                }
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Today's sessions
                        let todayBlocks = blocks.filter {
                            Calendar.current.isDateInToday($0.start)
                        }.sorted { $0.start > $1.start }

                        if !todayBlocks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("TODAY'S SESSIONS")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)

                                ForEach(todayBlocks) { block in
                                    HStack(spacing: 10) {
                                        Image(systemName: block.category == "Deep Work" ? "brain.head.profile" : "desktopcomputer")
                                            .font(.system(size: 14))
                                            .foregroundStyle(block.category == "Deep Work" ? accentColor : .secondary)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(block.topApp)
                                                .font(.system(.subheadline, design: .rounded))
                                                .lineLimit(1)
                                            Text("\(formatTime(block.start)) - \(formatTime(block.end))")
                                                .font(.system(.caption2, design: .rounded))
                                                .foregroundStyle(.tertiary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(formatMinutes(block.durationMinutes))
                                                .font(.system(.caption, design: .rounded).weight(.medium))
                                                .foregroundStyle(.secondary)
                                            Text(block.category)
                                                .font(.system(.caption2, design: .rounded))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Heatmap
                        DeskTimeHeatmapView()
                            .card()
                            .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Desk Time")
        .task { await loadData() }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func loadData() async {
        isLoading = true
        let calendar = Calendar.current
        let now = Date()
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now)!

        let fetched = (try? await service.fetchBlocks(from: ninetyDaysAgo, to: now)) ?? []

        guard !fetched.isEmpty else {
            isLoading = false
            return
        }

        blocks = fetched

        // Aggregate
        var daily: [Date: Int] = [:]
        var appDurations: [String: TimeInterval] = [:]
        var totalMins = 0
        var deepMins = 0
        var maxSessionMins = 0

        for block in fetched {
            let day = calendar.startOfDay(for: block.start)
            let mins = block.durationMinutes
            daily[day, default: 0] += mins
            totalMins += mins
            maxSessionMins = max(maxSessionMins, mins)

            if block.category == "Deep Work" {
                deepMins += mins
            }

            for event in block.events {
                appDurations[event.appName, default: 0] += event.duration
            }
        }

        totalMinutes = totalMins
        deepWorkMinutes = deepMins
        longestSession = maxSessionMins
        dailyData = daily

        let activeDays = daily.count
        avgPerDay = activeDays > 0 ? totalMins / activeDays : 0

        // App stats
        appStats = appDurations.map { app, duration in
            let mins = Int(duration / 60)
            let cat = deepWorkApps.contains(app) ? "Productive" : "Other"
            return (app: app, minutes: mins, category: cat)
        }
        .sorted { $0.minutes > $1.minutes }

        // Weekly buckets
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        var weekBuckets: [(label: String, minutes: Int)] = []
        for i in (0..<12).reversed() {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: calendar.startOfDay(for: now))!
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
            var weekMins = 0
            for (day, mins) in daily {
                if day >= weekStart && day < weekEnd {
                    weekMins += mins
                }
            }
            weekBuckets.append((label: formatter.string(from: weekStart), minutes: weekMins))
        }
        weeklyData = weekBuckets.map { (week: $0.label, minutes: $0.minutes) }

        isLoading = false
    }
}

private struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
