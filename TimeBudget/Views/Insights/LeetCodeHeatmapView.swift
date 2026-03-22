import SwiftUI

struct LeetCodeHeatmapView: View {
    @State private var calendarData: [Date: Int] = [:]
    @State private var stats: LeetCodeStats?
    @State private var recentSubmissions: [LeetCodeSubmission] = []
    @State private var isLoading = true
    @State private var hasData = false

    private let leetCode = LeetCodeService.shared
    private let accentColor = Color(hex: "#FFA116")

    var body: some View {
        VStack(spacing: 14) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading LeetCode data...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if !hasData {
                EmptyStateView(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "No LeetCode data yet",
                    subtitle: "Your submission history will appear here"
                )
            } else {
                // Stats
                if let stats = stats {
                    HStack(spacing: 0) {
                        DifficultyBadge(value: "\(stats.totalSolved)", label: "solved", color: accentColor)
                        DifficultyBadge(value: "\(stats.easySolved)", label: "easy", color: .green)
                        DifficultyBadge(value: "\(stats.mediumSolved)", label: "medium", color: .orange)
                        DifficultyBadge(value: "\(stats.hardSolved)", label: "hard", color: .red)
                    }
                }

                ContributionCalendarView(
                    data: calendarData,
                    accentColor: accentColor
                )

                // Recent submissions
                if !recentSubmissions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RECENT")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .tracking(0.5)

                        ForEach(recentSubmissions.prefix(5)) { submission in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.green)

                                Text(submission.title)
                                    .font(.system(.subheadline, design: .rounded))
                                    .lineLimit(1)

                                Spacer()

                                Text(submission.lang)
                                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(Capsule())

                                Text(relativeDate(submission.timestamp))
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
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
        hasData = !calendarData.isEmpty || stats != nil
        isLoading = false
    }
}

// MARK: - Difficulty Badge

private struct DifficultyBadge: View {
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
