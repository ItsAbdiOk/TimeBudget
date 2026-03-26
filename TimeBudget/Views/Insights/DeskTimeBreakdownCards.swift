import SwiftUI
import Charts

struct DeskTimeTierBreakdown: View {
    let breakdown: [(tier: ProductivityTier, minutes: Int)]
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME BREAKDOWN")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(0.5)

            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(breakdown, id: \.tier) { item in
                        let proportion = total > 0 ? CGFloat(item.minutes) / CGFloat(total) : 0
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(DeskTimeViewModel.colorForTier(item.tier))
                            .frame(width: max(geo.size.width * proportion - 1, 2))
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            ForEach(breakdown, id: \.tier) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(DeskTimeViewModel.colorForTier(item.tier))
                        .frame(width: 8, height: 8)
                    Text(item.tier.rawValue)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(DeskTimeViewModel.formatMinutes(item.minutes))
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
}

// MARK: - Website Breakdown

struct DeskTimeWebsiteBreakdown: View {
    let siteStats: [(site: String, minutes: Int, tier: ProductivityTier)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOP WEBSITES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(0.5)

            ForEach(siteStats.prefix(10), id: \.site) { site in
                HStack(spacing: 10) {
                    Circle()
                        .fill(DeskTimeViewModel.colorForTier(site.tier))
                        .frame(width: 8, height: 8)
                    Text(site.site)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(site.tier.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(DeskTimeViewModel.colorForTier(site.tier).opacity(0.12))
                        .foregroundStyle(DeskTimeViewModel.colorForTier(site.tier))
                        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                    Text(DeskTimeViewModel.formatMinutes(site.minutes))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .card()
    }
}

// MARK: - App Breakdown

struct DeskTimeAppBreakdown: View {
    let appStats: [(app: String, minutes: Int, tier: ProductivityTier, device: AWSourceDevice)]
    let hasIPhoneData: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOP APPS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(0.5)

            ForEach(Array(appStats.prefix(10).enumerated()), id: \.offset) { _, app in
                HStack(spacing: 10) {
                    Circle()
                        .fill(DeskTimeViewModel.colorForTier(app.tier))
                        .frame(width: 8, height: 8)
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
                        .background(DeskTimeViewModel.colorForTier(app.tier).opacity(0.12))
                        .foregroundStyle(DeskTimeViewModel.colorForTier(app.tier))
                        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                    Text(DeskTimeViewModel.formatMinutes(app.minutes))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .card()
    }
}

// MARK: - Weekly Trend

struct DeskTimeWeeklyTrend: View {
    let weeklyData: [(week: String, minutes: Int)]

    var body: some View {
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
}

#Preview("Tier Breakdown") {
    DeskTimeTierBreakdown(
        breakdown: [
            (tier: .deepWork, minutes: 120),
            (tier: .productive, minutes: 90),
            (tier: .neutral, minutes: 45),
            (tier: .distraction, minutes: 30)
        ],
        total: 285
    )
    .padding()
}
#Preview("Website Breakdown") {
    DeskTimeWebsiteBreakdown(siteStats: [
        (site: "github.com", minutes: 45, tier: .deepWork),
        (site: "stackoverflow.com", minutes: 20, tier: .productive),
        (site: "youtube.com", minutes: 15, tier: .distraction)
    ]).padding()
}
#Preview("App Breakdown") {
    DeskTimeAppBreakdown(
        appStats: [
            (app: "Xcode", minutes: 90, tier: .deepWork, device: .mac),
            (app: "Safari", minutes: 30, tier: .neutral, device: .mac)
        ],
        hasIPhoneData: false
    ).padding()
}
#Preview("Weekly Trend") {
    DeskTimeWeeklyTrend(weeklyData: [
        (week: "Mar 3", minutes: 300),
        (week: "Mar 10", minutes: 420),
        (week: "Mar 17", minutes: 360)
    ]).padding()
}
