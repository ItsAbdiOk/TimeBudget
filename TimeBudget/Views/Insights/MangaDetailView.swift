import SwiftUI
import Charts

struct MangaDetailView: View {
    @State private var allActivities: [AniListActivity] = []
    @State private var mangaStats: [(title: String, chapters: Int, minutes: Int)] = []
    @State private var weeklyData: [(week: String, minutes: Int)] = []
    @State private var dailyData: [Date: Int] = [:]
    @State private var totalChapters: Int = 0
    @State private var totalMinutes: Int = 0
    @State private var longestStreak: Int = 0
    @State private var isLoading = true

    private let aniList = AniListService.shared
    private let accentColor = Color(hex: "#AC8E68")

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
                            StatBadge(value: "\(totalChapters)", label: "chapters")
                            StatBadge(value: formatMinutes(totalMinutes), label: "reading")
                            StatBadge(value: "\(mangaStats.count)", label: "series")
                            StatBadge(value: "\(longestStreak)d", label: "best streak")
                        }
                        .card()
                        .padding(.horizontal, 16)

                        // Weekly reading trend
                        if !weeklyData.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("WEEKLY READING")
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

                        // Manga breakdown
                        if !mangaStats.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("SERIES BREAKDOWN")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)

                                ForEach(mangaStats.prefix(10), id: \.title) { manga in
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(accentColor)
                                            .frame(width: 8, height: 8)

                                        Text(manga.title)
                                            .font(.system(.subheadline, design: .rounded))
                                            .lineLimit(1)

                                        Spacer()

                                        Text("\(manga.chapters) ch")
                                            .font(.system(.caption, design: .rounded).weight(.medium))
                                            .foregroundStyle(.secondary)

                                        Text(formatMinutes(manga.minutes))
                                            .font(.system(.caption, design: .rounded).weight(.medium))
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 50, alignment: .trailing)
                                    }
                                }
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Heatmap
                        AniListHeatmapView()
                            .card()
                            .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Manga")
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

        let activities = (try? await aniList.fetchReadingActivity(from: ninetyDaysAgo, to: now)) ?? []

        guard !activities.isEmpty else {
            isLoading = false
            return
        }

        allActivities = activities

        // Total stats
        var chapters = 0
        var byTitle: [String: (chapters: Int, minutes: Int)] = [:]
        var daily: [Date: Int] = [:]

        for activity in activities {
            chapters += activity.chaptersRead
            let mins = activity.chaptersRead * aniList.minutesPerChapter
            byTitle[activity.mediaTitle, default: (chapters: 0, minutes: 0)].chapters += activity.chaptersRead
            byTitle[activity.mediaTitle, default: (chapters: 0, minutes: 0)].minutes += mins
            let day = calendar.startOfDay(for: activity.createdAt)
            daily[day, default: 0] += mins
        }

        totalChapters = chapters
        totalMinutes = chapters * aniList.minutesPerChapter
        dailyData = daily

        mangaStats = byTitle.map { (title: $0.key, chapters: $0.value.chapters, minutes: $0.value.minutes) }
            .sorted { $0.chapters > $1.chapters }

        // Weekly aggregation (last 12 weeks)
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

        // Longest streak
        let sortedDays = daily.keys.sorted()
        var maxStreak = 0
        var streak = 1
        for i in 1..<sortedDays.count {
            let diff = calendar.dateComponents([.day], from: sortedDays[i-1], to: sortedDays[i]).day ?? 0
            if diff == 1 {
                streak += 1
                maxStreak = max(maxStreak, streak)
            } else {
                streak = 1
            }
        }
        longestStreak = max(maxStreak, sortedDays.isEmpty ? 0 : 1)

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
