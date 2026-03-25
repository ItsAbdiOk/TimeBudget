import SwiftUI
import Charts

struct DeskTimeDetailView: View {
    @State private var blocks: [AWActivityBlock] = []
    @State private var allEvents: [AWEvent] = []
    @State private var appStats: [(app: String, minutes: Int, tier: ProductivityTier, device: AWSourceDevice)] = []
    @State private var siteStats: [(site: String, minutes: Int, tier: ProductivityTier)] = []
    @State private var hasIPhoneData: Bool = false
    @State private var weeklyData: [(week: String, minutes: Int)] = []
    @State private var dailyData: [Date: Int] = [:]
    @State private var totalMinutes: Int = 0
    @State private var productivityScore: Int = 0
    @State private var avgPerDay: Int = 0
    @State private var longestSession: Int = 0
    @State private var tierBreakdown: [(tier: ProductivityTier, minutes: Int)] = []
    @State private var isLoading = true
    @State private var aiRefinedCount: Int = 0
    @State private var selectedDevice: AWSourceDevice? = nil  // nil = All Devices
    @State private var macMinutes: Int = 0
    @State private var iphoneMinutes: Int = 0
    @State private var viewMode: ViewMode = .daily

    enum ViewMode: String, CaseIterable {
        case daily = "Today"
        case weekly = "Week"
    }

    private let service = ActivityWatchService.shared

    // MARK: - Filtered Data (by selectedDevice)

    private var filteredBlocks: [AWActivityBlock] {
        guard let device = selectedDevice else { return blocks }
        return blocks.filter { $0.dominantDevice == device }
    }

    private var filteredAppStats: [(app: String, minutes: Int, tier: ProductivityTier, device: AWSourceDevice)] {
        guard let device = selectedDevice else { return appStats }
        return appStats.filter { $0.device == device }
    }

    private var filteredSiteStats: [(site: String, minutes: Int, tier: ProductivityTier)] {
        guard selectedDevice != nil else { return siteStats }
        // Re-compute site stats from filtered blocks
        var siteDurations: [String: TimeInterval] = [:]
        for block in filteredBlocks {
            for event in block.events {
                if let site = event.siteName {
                    siteDurations[site, default: 0] += event.duration
                }
            }
        }
        return siteDurations.map { site, duration in
            let mins = Int(duration / 60)
            let tier = ProductivityClassifier.classify(app: "Google Chrome", site: site)
            return (site: site, minutes: mins, tier: tier)
        }.sorted { $0.minutes > $1.minutes }
    }

    private var filteredTotalMinutes: Int {
        guard let device = selectedDevice else { return totalMinutes }
        return device == .iphone ? iphoneMinutes : macMinutes
    }

    // Weekly-scoped blocks (last 7 days)
    private var weekBlocks: [AWActivityBlock] {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date()))!
        return filteredBlocks.filter { $0.start >= weekAgo }
    }

    // Today-scoped blocks
    private var todayBlocks: [AWActivityBlock] {
        filteredBlocks.filter { Calendar.current.isDateInToday($0.start) }
    }

    // Scope-aware blocks for breakdown sections
    private var scopedBlocks: [AWActivityBlock] {
        viewMode == .daily ? todayBlocks : weekBlocks
    }

    // MARK: - Scope-Aware Computed Data

    private var scopedTotalMinutes: Int {
        scopedBlocks.reduce(0) { $0 + $1.durationMinutes }
    }

    private var scopedLongestSession: Int {
        scopedBlocks.map(\.durationMinutes).max() ?? 0
    }

    private var scopedAvgPerDay: Int {
        let cal = Calendar.current
        let days = Set(scopedBlocks.map { cal.startOfDay(for: $0.start) }).count
        return days > 0 ? scopedTotalMinutes / days : 0
    }

    private var scopedTierBreakdown: [(tier: ProductivityTier, minutes: Int)] {
        var tierMins: [ProductivityTier: Int] = [:]
        for block in scopedBlocks {
            let tier = ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral
            tierMins[tier, default: 0] += block.durationMinutes
        }
        return tierMins
            .map { (tier: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
    }

    private var scopedAppStats: [(app: String, minutes: Int, tier: ProductivityTier, device: AWSourceDevice)] {
        var appDeviceDurations: [String: (duration: TimeInterval, device: AWSourceDevice)] = [:]
        for block in scopedBlocks {
            for event in block.events {
                if let device = selectedDevice, event.sourceDevice != device { continue }
                let key = "\(event.appName)|\(event.sourceDevice.rawValue)"
                let existing = appDeviceDurations[key]
                appDeviceDurations[key] = (
                    duration: (existing?.duration ?? 0) + event.duration,
                    device: event.sourceDevice
                )
            }
        }
        return appDeviceDurations.map { key, value in
            let appName = String(key.split(separator: "|").first ?? "")
            let mins = Int(value.duration / 60)
            let tier = ProductivityClassifier.classify(app: appName, site: nil)
            return (app: appName, minutes: mins, tier: tier, device: value.device)
        }
        .filter { $0.minutes > 0 }
        .sorted { $0.minutes > $1.minutes }
    }

    private var scopedSiteStats: [(site: String, minutes: Int, tier: ProductivityTier)] {
        var siteDurations: [String: TimeInterval] = [:]
        for block in scopedBlocks {
            for event in block.events {
                if let device = selectedDevice, event.sourceDevice != device { continue }
                if let site = event.siteName {
                    siteDurations[site, default: 0] += event.duration
                }
            }
        }
        return siteDurations.map { site, duration in
            let mins = Int(duration / 60)
            let tier = ProductivityClassifier.classify(app: "Google Chrome", site: site)
            return (site: site, minutes: mins, tier: tier)
        }
        .filter { $0.minutes > 0 }
        .sorted { $0.minutes > $1.minutes }
    }

    private var scopedProductivityScore: Int {
        let total = scopedTotalMinutes
        guard total > 0 else { return 0 }
        let deepMins = scopedTierBreakdown.first(where: { $0.tier == .deepWork })?.minutes ?? 0
        let productiveMins = scopedTierBreakdown.first(where: { $0.tier == .productive })?.minutes ?? 0
        let distractMins = scopedTierBreakdown.first(where: { $0.tier == .distraction })?.minutes ?? 0
        let score = Double(deepMins * 100 + productiveMins * 70 + (total - deepMins - productiveMins - distractMins) * 40) / Double(total)
        return min(100, max(0, Int(score)))
    }

    private var scopedMacMinutes: Int {
        scopedBlocks.filter { $0.dominantDevice == .mac }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var scopedIPhoneMinutes: Int {
        scopedBlocks.filter { $0.dominantDevice == .iphone }.reduce(0) { $0 + $1.durationMinutes }
    }

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
                            StatBadge(value: formatMinutes(scopedTotalMinutes), label: "total")
                            StatBadge(value: formatMinutes(scopedAvgPerDay), label: viewMode == .daily ? "avg/day" : "avg/day")
                            StatBadge(value: formatMinutes(scopedLongestSession), label: "longest")
                        }
                        .card()
                        .padding(.horizontal, 16)

                        // Daily/Weekly toggle
                        viewModePicker
                            .padding(.horizontal, 16)

                        // Device filter pills
                        if hasIPhoneData {
                            deviceFilterPills
                                .padding(.horizontal, 16)
                        }

                        // Visual timeline bar (today only)
                        if viewMode == .daily {
                            todayTimelineBar
                                .padding(.horizontal, 16)
                        }

                        // Tier breakdown bar
                        if !scopedTierBreakdown.isEmpty {
                            tierBreakdownCard
                                .padding(.horizontal, 16)
                        }

                        // Website breakdown
                        if !scopedSiteStats.isEmpty {
                            websiteBreakdownCard
                                .padding(.horizontal, 16)
                        }

                        // App breakdown
                        if !scopedAppStats.isEmpty {
                            appBreakdownCard
                                .padding(.horizontal, 16)
                        }

                        // Weekly trend (weekly view)
                        if viewMode == .weekly && !weeklyData.isEmpty {
                            weeklyTrendCard
                                .padding(.horizontal, 16)
                        }

                        // Sessions
                        sessionsCard
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
        let score = scopedProductivityScore
        return HStack(spacing: 18) {
            CircularProgress(
                progress: Double(score) / 100.0,
                lineWidth: 8,
                color: colorForScore(score),
                showLabel: false
            )
            .frame(width: 68, height: 68)
            .overlay {
                Text("\(score)")
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

    private func colorForScore(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color(.systemGreen)
        case 60..<80: return Color(.systemTeal)
        case 40..<60: return Color(.systemOrange)
        default: return Color(.systemRed)
        }
    }

    private var scoreLabel: String {
        let score = scopedProductivityScore
        let period = viewMode == .daily ? "day" : "week"
        switch score {
        case 80...100: return "Highly productive"
        case 60..<80: return "Productive \(period)"
        case 40..<60: return "Mixed focus"
        default: return "Distracted \(period)"
        }
    }

    private var scoreSummary: String {
        let breakdown = scopedTierBreakdown
        let deepMins = breakdown.first(where: { $0.tier == .deepWork })?.minutes ?? 0
        let distractMins = breakdown.first(where: { $0.tier == .distraction })?.minutes ?? 0
        if deepMins > 0 && distractMins > 0 {
            return "\(formatMinutes(deepMins)) deep work, \(formatMinutes(distractMins)) distractions"
        } else if deepMins > 0 {
            return "\(formatMinutes(deepMins)) of focused deep work"
        } else {
            return "\(formatMinutes(scopedTotalMinutes)) total screen time"
        }
    }

    // MARK: - Tier Breakdown Card

    private var tierBreakdownCard: some View {
        let breakdown = scopedTierBreakdown
        let total = scopedTotalMinutes
        return VStack(alignment: .leading, spacing: 12) {
            Text("TIME BREAKDOWN")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(0.5)

            // Horizontal stacked bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(breakdown, id: \.tier) { item in
                        let proportion = total > 0 ? CGFloat(item.minutes) / CGFloat(total) : 0
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(colorForTier(item.tier))
                            .frame(width: max(geo.size.width * proportion - 1, 2))
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            // Legend
            ForEach(breakdown, id: \.tier) { item in
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
                    let pct = total > 0 ? Int(Double(item.minutes) / Double(total) * 100) : 0
                    Text("\(pct)%")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .card()
    }

    // MARK: - Device Filter Pills

    private var deviceFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                devicePill(label: "All Devices", icon: "circle.grid.2x2", device: nil, minutes: scopedTotalMinutes)
                devicePill(label: "Mac", icon: "desktopcomputer", device: .mac, minutes: scopedMacMinutes)
                devicePill(label: "iPhone", icon: "iphone", device: .iphone, minutes: scopedIPhoneMinutes)
            }
        }
    }

    private func devicePill(label: String, icon: String, device: AWSourceDevice?, minutes: Int) -> some View {
        let isSelected = selectedDevice == device
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDevice = device
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                Text(formatMinutes(minutes))
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? .blue : Color(.secondaryLabel))
        }
        .buttonStyle(.plain)
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(viewMode == mode ? Color(.systemBackground) : Color.clear)
                                .shadow(color: viewMode == mode ? .black.opacity(0.08) : .clear, radius: 2, y: 1)
                        )
                        .foregroundStyle(viewMode == mode ? Color.primary : Color(.secondaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Today's Timeline Bar

    @ViewBuilder
    private var todayTimelineBar: some View {
        let todayBlocks = filteredBlocks
            .filter { Calendar.current.isDateInToday($0.start) }
            .sorted { $0.start < $1.start }

        if !todayBlocks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S TIMELINE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .tracking(0.5)

                // Time labels
                let earliest = todayBlocks.first!.start
                let latest = todayBlocks.last!.end
                let cal = Calendar.current
                let startHour = cal.component(.hour, from: earliest)
                let endHour = min(cal.component(.hour, from: latest) + 1, 24)
                let hourRange = max(endHour - startHour, 1)

                HStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        Text(formatHourLabel(hour))
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(Color(.tertiaryLabel))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Timeline bar
                GeometryReader { geo in
                    let totalSeconds = TimeInterval(hourRange * 3600)
                    let timelineStart = cal.date(bySettingHour: startHour, minute: 0, second: 0, of: Date())!

                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(.tertiarySystemFill))

                        // Activity blocks
                        ForEach(Array(todayBlocks.enumerated()), id: \.element.id) { _, block in
                            let offset = block.start.timeIntervalSince(timelineStart)
                            let duration = block.end.timeIntervalSince(block.start)
                            let x = max(0, CGFloat(offset / totalSeconds)) * geo.size.width
                            let w = max(3, CGFloat(duration / totalSeconds) * geo.size.width)

                            let tier = ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(colorForTier(tier))
                                .frame(width: min(w, geo.size.width - x), height: 28)
                                .overlay(alignment: .bottom) {
                                    if hasIPhoneData && block.dominantDevice == .iphone {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 3)
                                    }
                                }
                                .overlay {
                                    if w > 30 {
                                        Text(block.topSite ?? block.topApp)
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .lineLimit(1)
                                            .padding(.horizontal, 3)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .offset(x: x)
                        }
                    }
                }
                .frame(height: 28)

                // Device legend
                if hasIPhoneData {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(.tertiaryLabel))
                                .frame(width: 10, height: 3)
                            Text("Mac")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.blue)
                                .frame(width: 10, height: 3)
                            Text("iPhone")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                }
            }
            .card()
        }
    }

    private func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour == 12 { return "12 PM" }
        if hour < 12 { return "\(hour)" }
        return "\(hour - 12)"
    }

    // MARK: - Website Breakdown Card

    private var websiteBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOP WEBSITES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(0.5)

            ForEach(scopedSiteStats.prefix(10), id: \.site) { site in
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

            ForEach(Array(scopedAppStats.prefix(10).enumerated()), id: \.offset) { _, app in
                HStack(spacing: 10) {
                    Circle()
                        .fill(colorForTier(app.tier))
                        .frame(width: 8, height: 8)

                    // Show device icon when we have multi-device data
                    if hasIPhoneData {
                        Image(systemName: app.device == .iphone ? "iphone" : "desktopcomputer")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .frame(width: 14)
                    }

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
    private var sessionsCard: some View {
        let sessionBlocks = scopedBlocks.sorted { $0.start > $1.start }

        if !sessionBlocks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(viewMode == .daily ? "TODAY'S SESSIONS" : "THIS WEEK'S SESSIONS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .tracking(0.5)

                    Spacer()

                    if aiRefinedCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "brain")
                                .font(.system(size: 9, weight: .semibold))
                            Text("\(aiRefinedCount) AI refined")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color(.systemPurple))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.systemPurple).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                    }
                }
                .padding(.bottom, 12)

                ForEach(Array(sessionBlocks.prefix(viewMode == .daily ? 50 : 20).enumerated()), id: \.element.id) { index, block in
                    if index > 0 {
                        Divider()
                    }
                    HStack(spacing: 10) {
                        // Color stripe — uses effective (AI-refined) category
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(colorForTier(ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral))
                            .frame(width: 3, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(block.topSite ?? block.topApp)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                if block.isAIRefined {
                                    Image(systemName: "brain")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Color(.systemPurple))
                                }
                            }
                            HStack(spacing: 5) {
                                if block.topSite != nil {
                                    Text(block.topApp)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(.tertiaryLabel))
                                }
                                // Device label
                                HStack(spacing: 3) {
                                    Image(systemName: block.dominantDevice == .iphone ? "iphone" : "desktopcomputer")
                                        .font(.system(size: 8))
                                    Text(block.dominantDevice == .iphone ? "iPhone" : "Mac")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(Color(.tertiaryLabel))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

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
                            HStack(spacing: 3) {
                                if block.isAIRefined {
                                    Text(block.effectiveCategory)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color(.systemPurple))
                                } else {
                                    Text(block.effectiveCategory)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(colorForTier(ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral))
                                }
                            }
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

    // MARK: - AI Categorization

    @available(iOS 26, *)
    private func applyAICategorization(to blocks: inout [AWActivityBlock], todayBlocks: [AWActivityBlock]) async {
        // Ensure the model is ready (may still be warming up from app launch)
        let intelligence = IntelligenceService.shared
        if await !intelligence.isReady {
            print("[DeskTime] Intelligence not ready, warming up...")
            await intelligence.warmUp()
        }
        guard await intelligence.isReady else {
            print("[DeskTime] Intelligence unavailable on this device")
            return
        }

        // Use default categories matching the productivity tiers + common TimeBudget categories
        let validCategories = ["Deep Work", "Work", "Meetings", "Reading", "Podcast", "Exercise",
                               "Walking", "Running", "Cycling", "Commute", "Sleep", "Fajr",
                               "Desk Time", "Other", "Productive", "Neutral", "Distraction"]

        // Build a lookup from UUID string to index in the blocks array
        var idToIndex: [String: Int] = [:]
        for i in blocks.indices {
            idToIndex[blocks[i].id.uuidString] = i
        }

        let items = todayBlocks.prefix(50).map { block in
            let urls = block.events.compactMap { $0.url }.prefix(3)
            let urlString = urls.isEmpty ? nil : urls.joined(separator: ", ")
            return UncategorizedItem(
                id: block.id.uuidString,
                app: block.topApp,
                title: block.events.first?.windowTitle ?? "",
                site: urlString ?? block.topSite,
                durationMinutes: block.durationMinutes
            )
        }

        print("[DeskTime] Sending \(items.count) blocks to AI for categorization")
        for item in items.prefix(3) {
            print("[DeskTime]   - \(item.app) | \(item.site ?? "no site") | \(item.title.prefix(40))")
        }

        do {
            let results = try await intelligence.categorize(
                items: items,
                validCategories: validCategories
            )
            var applied = 0
            for item in results {
                if let idx = idToIndex[item.id] {
                    blocks[idx].aiCategory = item.category
                    applied += 1
                }
            }
            print("[DeskTime] AI categorized \(results.count) items, applied \(applied) to blocks")
            for item in results.prefix(5) {
                let original = todayBlocks.first(where: { $0.id.uuidString == item.id })?.category ?? "?"
                print("[DeskTime]   \(original) → \(item.category) (conf: \(String(format: "%.0f%%", item.confidence * 100)))")
            }
        } catch {
            print("[DeskTime] AI categorization failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        let calendar = Calendar.current
        let now = Date()
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now)!

        var fetched = (try? await service.fetchBlocks(from: ninetyDaysAgo, to: now)) ?? []

        guard !fetched.isEmpty else {
            isLoading = false
            return
        }

        // Apply AI categorization to today's blocks
        if #available(iOS 26, *) {
            let enabled = UserDefaults.standard.bool(forKey: "intelligence_categorization_enabled")
            if enabled {
                let todayStart = calendar.startOfDay(for: now)
                let todayBlocks = fetched.filter { $0.start >= todayStart }
                if !todayBlocks.isEmpty {
                    await applyAICategorization(to: &fetched, todayBlocks: todayBlocks)
                }
            }
        }

        blocks = fetched
        aiRefinedCount = fetched.filter { calendar.isDateInToday($0.start) && $0.isAIRefined }.count

        // Also fetch raw events for today for detailed analysis
        let todayEvents = (try? await service.fetchRawEvents(for: now)) ?? []
        allEvents = todayEvents

        // Productivity score from today's raw events
        productivityScore = ProductivityClassifier.productivityScore(events: todayEvents)

        // Aggregate
        var daily: [Date: Int] = [:]
        // Key: "appName|device" to separate Mac vs iPhone apps
        var appDeviceDurations: [String: (duration: TimeInterval, device: AWSourceDevice)] = [:]
        var siteDurations: [String: TimeInterval] = [:]
        var totalMins = 0
        var maxSessionMins = 0
        var tierMins: [ProductivityTier: Int] = [:]
        var seenIPhone = false

        for block in fetched {
            let day = calendar.startOfDay(for: block.start)
            let mins = block.durationMinutes
            daily[day, default: 0] += mins
            totalMins += mins
            maxSessionMins = max(maxSessionMins, mins)

            for event in block.events {
                let device = event.sourceDevice
                if device == .iphone { seenIPhone = true }
                let key = "\(event.appName)|\(device.rawValue)"
                let existing = appDeviceDurations[key]
                appDeviceDurations[key] = (
                    duration: (existing?.duration ?? 0) + event.duration,
                    device: device
                )
                if let site = event.siteName {
                    siteDurations[site, default: 0] += event.duration
                }
            }
        }

        hasIPhoneData = seenIPhone

        // Compute per-device totals
        var macMins = 0
        var iphoneMins = 0
        for block in fetched {
            let device = block.dominantDevice
            if device == .iphone {
                iphoneMins += block.durationMinutes
            } else {
                macMins += block.durationMinutes
            }
        }
        macMinutes = macMins
        iphoneMinutes = iphoneMins

        // Tier breakdown: use AI-refined categories for today's blocks when available
        let todayBlocksForTier = fetched.filter { calendar.isDateInToday($0.start) }
        if !todayBlocksForTier.isEmpty {
            for block in todayBlocksForTier {
                let tier = ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral
                tierMins[tier, default: 0] += block.durationMinutes
            }
        } else {
            for event in todayEvents {
                let tier = ProductivityClassifier.classify(app: event.appName, site: event.siteName)
                tierMins[tier, default: 0] += event.durationMinutes
            }
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

        // App stats (device-aware)
        appStats = appDeviceDurations.map { key, value in
            let appName = String(key.split(separator: "|").first ?? "")
            let mins = Int(value.duration / 60)
            let tier = ProductivityClassifier.classify(app: appName, site: nil)
            return (app: appName, minutes: mins, tier: tier, device: value.device)
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
