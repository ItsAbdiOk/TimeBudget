import SwiftUI

struct PodcastHeatmapView: View {
    @State private var dailyData: [Date: Int] = [:]
    @State private var totalEpisodes: Int = 0
    @State private var totalMinutes: Int = 0
    @State private var topPodcast: String?
    @State private var isLoading = true
    @State private var hasData = false

    private let service = PocketCastsService.shared
    private let accentColor = Color(hex: "#F43F5E")

    var body: some View {
        VStack(spacing: 14) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading podcast data...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if !hasData {
                EmptyStateView(
                    icon: "headphones",
                    title: "No podcast data yet",
                    subtitle: "Your Pocket Casts listening will appear here"
                )
            } else {
                // Stats row
                HStack(spacing: 0) {
                    StatBadge(
                        value: "\(totalEpisodes)",
                        label: "episodes",
                        icon: "headphones",
                        color: accentColor
                    )
                    StatBadge(
                        value: formatMinutes(totalMinutes),
                        label: "listening",
                        icon: "clock.fill",
                        color: accentColor
                    )
                    if let top = topPodcast {
                        VStack(spacing: 4) {
                            Text(top)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            Text("most played")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
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

        let episodes: [PocketCastsEpisode]
        do {
            episodes = try await service.fetchEpisodes(from: start, to: now)
        } catch {
            isLoading = false
            return
        }

        guard !episodes.isEmpty else {
            isLoading = false
            return
        }

        var daily: [Date: Int] = [:]
        var podcastCounts: [String: Int] = [:]
        var totalMins = 0

        for episode in episodes {
            guard let played = episode.lastPlayedAt else { continue }
            let day = calendar.startOfDay(for: played)
            let mins = episode.listenedMinutes
            daily[day, default: 0] += mins
            totalMins += mins
            podcastCounts[episode.podcastTitle, default: 0] += 1
        }

        dailyData = daily
        totalEpisodes = episodes.count
        totalMinutes = totalMins
        topPodcast = podcastCounts.max(by: { $0.value < $1.value })?.key
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
