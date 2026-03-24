import SwiftUI
import Charts

struct LeetCodeDetailView: View {
    @State private var stats: LeetCodeStats?
    @State private var calendarData: [Date: Int] = [:]
    @State private var recentSubmissions: [LeetCodeSubmission] = []
    @State private var weeklyData: [(week: String, count: Int)] = []
    @State private var currentStreak: Int = 0
    @State private var totalDays: Int = 0
    @State private var isLoading = true

    private let leetCode = LeetCodeService.shared
    private let accentColor = Color(hex: "#FFA116")

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else {
                        // Difficulty breakdown
                        if let stats = stats {
                            VStack(spacing: 12) {
                                HStack(spacing: 0) {
                                    DiffBadge(value: "\(stats.totalSolved)", label: "solved", color: accentColor)
                                    DiffBadge(value: "\(stats.easySolved)", label: "easy", color: Color(.systemGreen))
                                    DiffBadge(value: "\(stats.mediumSolved)", label: "medium", color: Color(.systemOrange))
                                    DiffBadge(value: "\(stats.hardSolved)", label: "hard", color: Color(.systemRed))
                                }

                                // Difficulty progress bars
                                VStack(spacing: 8) {
                                    DifficultyBar(label: "Easy", solved: stats.easySolved, total: stats.totalSolved, color: Color(.systemGreen))
                                    DifficultyBar(label: "Medium", solved: stats.mediumSolved, total: stats.totalSolved, color: Color(.systemOrange))
                                    DifficultyBar(label: "Hard", solved: stats.hardSolved, total: stats.totalSolved, color: Color(.systemRed))
                                }

                                HStack(spacing: 0) {
                                    DiffBadge(value: "#\(stats.ranking)", label: "ranking", color: Color(.systemPurple))
                                    DiffBadge(value: "\(totalDays)", label: "active days", color: accentColor)
                                    DiffBadge(value: "\(currentStreak)", label: "day streak", color: Color(.systemGreen))
                                }
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Weekly submissions chart
                        if !weeklyData.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("WEEKLY SUBMISSIONS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(.secondaryLabel))
                                    .tracking(0.5)

                                Chart(weeklyData, id: \.week) { item in
                                    BarMark(
                                        x: .value("Week", item.week),
                                        y: .value("Problems", item.count)
                                    )
                                    .foregroundStyle(accentColor.gradient)
                                    .cornerRadius(4)
                                }
                                .chartYAxisLabel("Problems")
                                .frame(height: 200)
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Heatmap
                        LeetCodeHeatmapView()
                            .card()
                            .padding(.horizontal, 16)

                        // All recent submissions (show more than the heatmap card)
                        if !recentSubmissions.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("RECENT ACCEPTED")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(.secondaryLabel))
                                    .tracking(0.5)

                                ForEach(recentSubmissions) { submission in
                                    HStack(spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color(.systemGreen))

                                        Text(submission.title)
                                            .font(.system(.subheadline))
                                            .lineLimit(1)

                                        Spacer()

                                        if !submission.topicTag.isEmpty {
                                            Text(submission.topicTag)
                                                .font(.system(.caption2).weight(.medium))
                                                .foregroundStyle(Color(.secondaryLabel))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color(.tertiarySystemFill))
                                                .clipShape(Capsule())
                                        }

                                        Text(relativeDate(submission.timestamp))
                                            .font(.system(.caption2))
                                            .foregroundStyle(Color(.tertiaryLabel))
                                    }
                                }
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("LeetCode")
        .task { await loadData() }
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "1d ago" }
        if days < 7 { return "\(days)d ago" }
        return "\(days / 7)w ago"
    }

    private func loadData() async {
        isLoading = true

        async let calendarTask = try? leetCode.fetchSubmissionCalendar()
        async let statsTask = try? leetCode.fetchStats()
        async let submissionsTask = try? leetCode.fetchRecentSubmissions(limit: 10)

        calendarData = await calendarTask ?? [:]
        stats = await statsTask
        recentSubmissions = await submissionsTask ?? []

        // Weekly aggregation
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        var weekBuckets: [(label: String, count: Int)] = []
        for i in (0..<12).reversed() {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: calendar.startOfDay(for: now))!
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
            var count = 0
            for (day, submissions) in calendarData {
                if day >= weekStart && day < weekEnd {
                    count += submissions
                }
            }
            weekBuckets.append((label: formatter.string(from: weekStart), count: count))
        }
        weeklyData = weekBuckets.map { (week: $0.label, count: $0.count) }

        // Active days and streak
        totalDays = calendarData.values.filter { $0 > 0 }.count

        let sortedDays = calendarData.keys.sorted()
        var streak = 0
        var checkDate = calendar.startOfDay(for: now)
        let activeDays = Set(sortedDays)
        while activeDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        currentStreak = streak

        isLoading = false
    }
}

private struct DiffBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3).weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DifficultyBar: View {
    let label: String
    let solved: Int
    let total: Int
    let color: Color

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return Double(solved) / Double(total)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.caption).weight(.medium))
                .frame(width: 55, alignment: .leading)
                .foregroundStyle(Color(.secondaryLabel))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(.tertiarySystemFill))

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color)
                        .frame(width: max(geo.size.width * ratio, 2))
                }
            }
            .frame(height: 8)

            Text("\(solved)")
                .font(.system(.caption2).weight(.medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .frame(width: 30, alignment: .trailing)
        }
    }
}
