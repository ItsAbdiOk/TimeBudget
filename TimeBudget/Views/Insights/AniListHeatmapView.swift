import SwiftUI

struct AniListHeatmapView: View {
    @State private var dailyData: [Date: Int] = [:]
    @State private var totalChapters: Int = 0
    @State private var totalMinutes: Int = 0
    @State private var topManga: String?
    @State private var isLoading = true
    @State private var hasData = false

    private let aniList = AniListService.shared
    private let accentColor = Color(hex: "#AC8E68")

    var body: some View {
        VStack(spacing: 14) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading AniList data...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if !hasData {
                EmptyStateView(
                    icon: "book.closed",
                    title: "No reading data yet",
                    subtitle: "Your AniList manga activity will appear here"
                )
            } else {
                // Stats row
                if totalChapters > 0 {
                    HStack(spacing: 0) {
                        StatBadge(
                            value: "\(totalChapters)",
                            label: "chapters",
                            icon: "book.fill",
                            color: accentColor
                        )
                        StatBadge(
                            value: formatMinutes(totalMinutes),
                            label: "reading",
                            icon: "clock.fill",
                            color: accentColor
                        )
                        if let top = topManga {
                            VStack(spacing: 4) {
                                Text(top)
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                Text("most read")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
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

        let twelveWeeksAgo = Calendar.current.date(byAdding: .day, value: -84, to: Date())!

        let activities: [AniListActivity]
        do {
            activities = try await aniList.fetchReadingActivity(from: twelveWeeksAgo, to: Date())
        } catch {
            isLoading = false
            return
        }

        guard !activities.isEmpty else {
            isLoading = false
            return
        }

        let calendar = Calendar.current
        var daily: [Date: Int] = [:]
        var chapters = 0
        var mangaCounts: [String: Int] = [:]

        for activity in activities {
            let day = calendar.startOfDay(for: activity.createdAt)
            let readingMinutes = activity.chaptersRead * aniList.minutesPerChapter
            daily[day, default: 0] += readingMinutes
            chapters += activity.chaptersRead
            mangaCounts[activity.mediaTitle, default: 0] += activity.chaptersRead
        }

        dailyData = daily
        totalChapters = chapters
        totalMinutes = chapters * aniList.minutesPerChapter
        topManga = mangaCounts.max(by: { $0.value < $1.value })?.key
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
                .font(.system(.title3, design: .rounded).weight(.semibold))
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
