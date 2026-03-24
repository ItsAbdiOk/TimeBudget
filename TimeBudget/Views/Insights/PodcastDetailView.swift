import SwiftUI
import Charts

struct PodcastDetailView: View {
    @State private var episodes: [PocketCastsEpisode] = []
    @State private var podcastStats: [(title: String, episodes: Int, minutes: Int)] = []
    @State private var weeklyData: [(week: String, minutes: Int)] = []
    @State private var dailyData: [Date: Int] = [:]
    @State private var totalEpisodes: Int = 0
    @State private var totalMinutes: Int = 0
    @State private var longestStreak: Int = 0
    @State private var avgPerDay: Int = 0
    @State private var isLoading = true

    private let service = PocketCastsService.shared
    private let accentColor = Color(hex: "#F43F5E")

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else if episodes.isEmpty {
                        EmptyStateView(
                            icon: "headphones",
                            title: "No podcast data",
                            subtitle: "Listen to podcasts on Pocket Casts and they'll show up here"
                        )
                    } else {
                        // Summary stats
                        HStack(spacing: 0) {
                            StatBadge(value: "\(totalEpisodes)", label: "episodes")
                            StatBadge(value: formatMinutes(totalMinutes), label: "listening")
                            StatBadge(value: "\(avgPerDay)m", label: "avg/day")
                            StatBadge(value: "\(longestStreak)d", label: "streak")
                        }
                        .card()
                        .padding(.horizontal, 16)

                        // Weekly listening trend
                        if !weeklyData.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("WEEKLY LISTENING")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(.secondaryLabel))
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

                        // Podcast breakdown
                        if !podcastStats.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("TOP PODCASTS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(.secondaryLabel))
                                    .tracking(0.5)

                                ForEach(podcastStats.prefix(10), id: \.title) { podcast in
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(accentColor)
                                            .frame(width: 8, height: 8)

                                        Text(podcast.title)
                                            .font(.system(.subheadline))
                                            .lineLimit(1)

                                        Spacer()

                                        Text("\(podcast.episodes) ep")
                                            .font(.system(.caption).weight(.medium))
                                            .foregroundStyle(Color(.secondaryLabel))

                                        Text(formatMinutes(podcast.minutes))
                                            .font(.system(.caption).weight(.medium))
                                            .foregroundStyle(Color(.tertiaryLabel))
                                            .frame(width: 55, alignment: .trailing)
                                    }
                                }
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Recent episodes
                        if !episodes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("RECENT EPISODES")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(.secondaryLabel))
                                    .tracking(0.5)

                                ForEach(episodes.prefix(15)) { episode in
                                    HStack(spacing: 10) {
                                        Image(systemName: episode.playingStatus == 3 ? "checkmark.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(episode.playingStatus == 3 ? Color(.systemGreen) : accentColor)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(episode.title)
                                                .font(.system(.subheadline))
                                                .lineLimit(1)
                                            Text(episode.podcastTitle)
                                                .font(.system(.caption2))
                                                .foregroundStyle(Color(.tertiaryLabel))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(formatMinutes(episode.listenedMinutes))
                                            .font(.system(.caption2).weight(.medium))
                                            .foregroundStyle(Color(.secondaryLabel))
                                    }
                                }
                            }
                            .card()
                            .padding(.horizontal, 16)
                        }

                        // Heatmap
                        PodcastHeatmapView()
                            .card()
                            .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Podcasts")
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

        let fetched = (try? await service.fetchEpisodes(from: ninetyDaysAgo, to: now)) ?? []

        guard !fetched.isEmpty else {
            isLoading = false
            return
        }

        // Sort by most recent first
        episodes = fetched.sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }

        // Aggregate
        var byPodcast: [String: (episodes: Int, minutes: Int)] = [:]
        var daily: [Date: Int] = [:]
        var totalMins = 0

        for episode in fetched {
            guard let played = episode.lastPlayedAt else { continue }
            let mins = episode.listenedMinutes
            totalMins += mins
            let day = calendar.startOfDay(for: played)
            daily[day, default: 0] += mins
            byPodcast[episode.podcastTitle, default: (episodes: 0, minutes: 0)].episodes += 1
            byPodcast[episode.podcastTitle, default: (episodes: 0, minutes: 0)].minutes += mins
        }

        totalEpisodes = fetched.count
        totalMinutes = totalMins
        dailyData = daily

        // Average minutes per active day
        let activeDays = daily.count
        avgPerDay = activeDays > 0 ? totalMins / activeDays : 0

        // Podcast breakdown sorted by time
        podcastStats = byPodcast.map { (title: $0.key, episodes: $0.value.episodes, minutes: $0.value.minutes) }
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
                .font(.system(.title3).weight(.semibold).monospacedDigit())
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}
