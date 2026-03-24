import SwiftUI
import Charts

struct DeskTimeDetailView: View {
    @State private var blocks: [AWActivityBlock] = []
    @State private var allEvents: [AWEvent] = []
    @State private var appStats: [(app: String, minutes: Int, tier: ProductivityTier)] = []
    @State private var siteStats: [(site: String, minutes: Int, tier: ProductivityTier)] = []
    @State private var weeklyData: [(week: String, minutes: Int)] = []
    @State private var dailyData: [Date: Int] = [:]
    @State private var totalMinutes: Int = 0
    @State private var productivityScore: Int = 0
    @State private var avgPerDay: Int = 0
    @State private var longestSession: Int = 0
    @State private var tierBreakdown: [(tier: ProductivityTier, minutes: Int)] = []
    @State private var isLoading = true

    private let service = ActivityWatchService.shared

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

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
                        // Productivity Score Card
                        productivityScoreCard
                            .padding(.horizontal, 16)

                        // Summary stats
                        HStack(spacing: 0) {
                            StatBadge(value: formatMinutes(totalMinutes), label: "total")
                            StatBadge(value: "\(avgPerDay)m", label: "avg/day")
                            StatBadge(value: formatMinutes(longestSession), label: "longest")
                        }
                        .card()
                        .padding(.horizontal, 16)

                        // Tier breakdown bar
                        if !tierBreakdown.isEmpty {
                            tierBreakdownCard
                                .padding(.horizontal, 16)
                        }

                        // Website breakdown
                        if !siteStats.isEmpty {
                            websiteBreakdownCard
                                .padding(.horizontal, 16)
                        }

                        // App breakdown
                        if !appStats.isEmpty {
                            appBreakdownCard
                                .padding(.horizontal, 16)
                        }

                        // Weekly trend
                        if !weeklyData.isEmpty {
                            weeklyTrendCard
                                .padding(.horizontal, 16)
                        }

                        // Today's sessions
                        todaySessionsCard
                            .padding(.horizontal, 16)

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

    // MARK: - Productivity Score Card

    private var productivityScoreCard: some View {
        HStack(spacing: 18) {
            CircularProgress(
                progress: Double(productivityScore) / 100.0,
                lineWidth: 8,
                color: scoreColor,
                showLabel: false
            )
            .frame(width: 68, height: 68)
            .overlay {
                Text("\(productivityScore)")
                    .font(.system(size: 26, weight: .semibold))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("PRODUCTIVITY SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color(.secondaryLabel))

                Text(scoreLabel)
                    .font(.system(size: 20, weight: .semibold))

                Text(scoreSummary)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .heroCard()
    }

    private var scoreColor: Color {
        switch productivityScore {
        case 80...100: return Color(.systemGreen)
        case 60..<80: return Color(.systemTeal)
        case 40..<60: return Color(.systemOrange)
        default: return Color(.systemRed)
        }
    }

    private var scoreLabel: String {
        switch productivityScore {
        case 80...100: return "Highly productive"
        case 60..<80: return "Productive day"
        case 40..<60: return "Mixed focus"
        default: return "Distracted day"
        }
    }

    private var scoreSummary: String {
        let deepMins = tierBreakdown.first(where: { $0.tier == .deepWork })?.minutes ?? 0
        let distractMins = tierBreakdown.first(where: { $0.tier == .distraction })?.minutes ?? 0
        if deepMins > 0 && distractMins > 0 {
            return "\(formatMinutes(deepMins)) deep work, \(formatMinutes(distractMins)) distractions"
        } else if deepMins > 0 {
            return "\(formatMinutes(deepMins)) of focused deep work"
        } else {
            return "\(formatMinutes(totalMinutes)) total screen time today"
        }
    }

    // MARK: - Tier Breakdown Card

    private var tierBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME BREAKDOWN")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(0.5)

            // Horizontal stacked bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(tierBreakdown, id: \.tier) { item in
                        let proportion = totalMinutes > 0 ? CGFloat(item.minutes) / CGFloat(totalMinutes) : 0
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(colorForTier(item.tier))
                            .frame(width: max(geo.size.width * proportion - 1, 2))
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            // Legend
            ForEach(tierBreakdown, id: \.tier) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(colorForTier(item.tier))
                        .frame(width: 8, height: 8)
                    Text(item.tier.rawValue)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(formatMinutes(item.minutes))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color(.secondaryLabel))
                    let pct = totalMinutes > 0 ? Int(Double(item.minutes) / Double(totalMinutes) * 100) : 0
                    Text("\(pct)%")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .card()
    }

    // MARK: - Website Breakdown Card

    private var websiteBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOP WEBSITES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(0.5)

            ForEach(siteStats.prefix(10), id: \.site) { site in
                HStack(spacing: 10) {
                    Circle()
                        .fill(colorForTier(site.tier))
                        .frame(width: 8, height: 8)

                    Text(site.site)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    Spacer()

                    Text(site.tier.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(colorForTier(site.tier).opacity(0.12))
                        .foregroundStyle(colorForTier(site.tier))
                        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))

                    Text(formatMinutes(site.minutes))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .card()
    }

    // MARK: - App Breakdown Card

    private var appBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOP APPS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(0.5)

            ForEach(appStats.prefix(10), id: \.app) { app in
                HStack(spacing: 10) {
                    Circle()
                        .fill(colorForTier(app.tier))
                        .frame(width: 8, height: 8)

                    Text(app.app)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    Spacer()

                    Text(app.tier.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(colorForTier(app.tier).opacity(0.12))
                        .foregroundStyle(colorForTier(app.tier))
                        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))

                    Text(formatMinutes(app.minutes))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .card()
    }

    // MARK: - Weekly Trend Card

    private var weeklyTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WEEKLY DESK TIME")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(0.5)

            Chart(weeklyData, id: \.week) { item in
                BarMark(
                    x: .value("Week", item.week),
                    y: .value("Hours", Double(item.minutes) / 60.0)
                )
                .foregroundStyle(Color(.systemPurple).gradient)
                .cornerRadius(4)
            }
            .chartYAxisLabel("Hours")
            .frame(height: 200)
        }
        .card()
    }

    // MARK: - Today's Sessions Card

    @ViewBuilder
    private var todaySessionsCard: some View {
        let todayBlocks = blocks.filter {
            Calendar.current.isDateInToday($0.start)
        }.sorted { $0.start > $1.start }

        if !todayBlocks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("TODAY'S SESSIONS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .tracking(0.5)
                    .padding(.bottom, 12)

                ForEach(Array(todayBlocks.enumerated()), id: \.element.id) { index, block in
                    if index > 0 {
                        Divider()
                    }
                    HStack(spacing: 10) {
                        // Color stripe
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(colorForTier(ProductivityTier(rawValue: block.category) ?? .neutral))
                            .frame(width: 3, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.topSite ?? block.topApp)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                if block.topSite != nil {
                                    Text(block.topApp)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(.tertiaryLabel))
                                }
                                Text("\(formatTime(block.start))–\(formatTime(block.end))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatMinutes(block.durationMinutes))
                                .font(.system(size: 13, weight: .medium))
                                .monospacedDigit()
                            Text(block.category)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(colorForTier(ProductivityTier(rawValue: block.category) ?? .neutral))
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .card()
        }
    }

    // MARK: - Helpers

    private func colorForTier(_ tier: ProductivityTier) -> Color {
        switch tier {
        case .deepWork: return Color(.systemGreen)
        case .productive: return Color(.systemTeal)
        case .neutral: return Color(.systemOrange)
        case .distraction: return Color(.systemRed)
        }
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

    // MARK: - Data Loading

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

        // Also fetch raw events for today for detailed analysis
        let todayEvents = (try? await service.fetchRawEvents(for: now)) ?? []
        allEvents = todayEvents

        // Productivity score from today's raw events
        productivityScore = ProductivityClassifier.productivityScore(events: todayEvents)

        // Aggregate
        var daily: [Date: Int] = [:]
        var appDurations: [String: TimeInterval] = [:]
        var siteDurations: [String: TimeInterval] = [:]
        var totalMins = 0
        var maxSessionMins = 0
        var tierMins: [ProductivityTier: Int] = [:]

        for block in fetched {
            let day = calendar.startOfDay(for: block.start)
            let mins = block.durationMinutes
            daily[day, default: 0] += mins
            totalMins += mins
            maxSessionMins = max(maxSessionMins, mins)

            for event in block.events {
                appDurations[event.appName, default: 0] += event.duration
                if let site = event.siteName {
                    siteDurations[site, default: 0] += event.duration
                }
            }
        }

        // Tier breakdown from today's events
        for event in todayEvents {
            let tier = ProductivityClassifier.classify(app: event.appName, site: event.siteName)
            tierMins[tier, default: 0] += event.durationMinutes
        }

        totalMinutes = totalMins
        longestSession = maxSessionMins
        dailyData = daily

        let activeDays = daily.count
        avgPerDay = activeDays > 0 ? totalMins / activeDays : 0

        // Tier breakdown sorted by time
        tierBreakdown = tierMins
            .map { (tier: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }

        // App stats
        appStats = appDurations.map { app, duration in
            let mins = Int(duration / 60)
            let tier = ProductivityClassifier.classify(app: app, site: nil)
            return (app: app, minutes: mins, tier: tier)
        }
        .sorted { $0.minutes > $1.minutes }

        // Site stats
        siteStats = siteDurations.map { site, duration in
            let mins = Int(duration / 60)
            let tier = ProductivityClassifier.classify(app: "Google Chrome", site: site)
            return (site: site, minutes: mins, tier: tier)
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
                .font(.system(.title3).weight(.semibold).monospacedDigit())
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}
