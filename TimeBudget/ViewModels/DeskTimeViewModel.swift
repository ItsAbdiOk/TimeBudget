import SwiftUI
import Observation

@Observable
final class DeskTimeViewModel {

    enum ViewMode: String, CaseIterable {
        case daily = "Today"
        case weekly = "Week"
    }

    var blocks: [AWActivityBlock] = []
    var allEvents: [AWEvent] = []
    var appStats: [(app: String, minutes: Int, tier: ProductivityTier, device: AWSourceDevice)] = []
    var siteStats: [(site: String, minutes: Int, tier: ProductivityTier)] = []
    var hasIPhoneData: Bool = false
    var weeklyData: [(week: String, minutes: Int)] = []
    var dailyData: [Date: Int] = [:]
    var totalMinutes: Int = 0
    var productivityScore: Int = 0
    var avgPerDay: Int = 0
    var longestSession: Int = 0
    var tierBreakdown: [(tier: ProductivityTier, minutes: Int)] = []
    var isLoading = true
    var aiRefinedCount: Int = 0
    var selectedDevice: AWSourceDevice? = nil
    var macMinutes: Int = 0
    var iphoneMinutes: Int = 0
    var viewMode: ViewMode = .daily

    let service = ActivityWatchService.shared

    var filteredBlocks: [AWActivityBlock] {
        guard let device = selectedDevice else { return blocks }
        return blocks.filter { $0.dominantDevice == device }
    }

    var filteredTotalMinutes: Int {
        guard let device = selectedDevice else { return totalMinutes }
        return device == .iphone ? iphoneMinutes : macMinutes
    }

    var weekBlocks: [AWActivityBlock] {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date()))!
        return filteredBlocks.filter { $0.start >= weekAgo }
    }

    var todayBlocks: [AWActivityBlock] {
        filteredBlocks.filter { Calendar.current.isDateInToday($0.start) }
    }

    var scopedBlocks: [AWActivityBlock] {
        viewMode == .daily ? todayBlocks : weekBlocks
    }

    var scopedTotalMinutes: Int {
        scopedBlocks.reduce(0) { $0 + $1.durationMinutes }
    }

    var scopedLongestSession: Int {
        scopedBlocks.map(\.durationMinutes).max() ?? 0
    }

    var scopedAvgPerDay: Int {
        let cal = Calendar.current
        let days = Set(scopedBlocks.map { cal.startOfDay(for: $0.start) }).count
        return days > 0 ? scopedTotalMinutes / days : 0
    }

    var scopedTierBreakdown: [(tier: ProductivityTier, minutes: Int)] {
        var tierMins: [ProductivityTier: Int] = [:]
        for block in scopedBlocks {
            let tier = ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral
            tierMins[tier, default: 0] += block.durationMinutes
        }
        return tierMins
            .map { (tier: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
    }

    var scopedAppStats: [(app: String, minutes: Int, tier: ProductivityTier, device: AWSourceDevice)] {
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

    var scopedSiteStats: [(site: String, minutes: Int, tier: ProductivityTier)] {
        var siteDurations: [String: TimeInterval] = [:]
        var unmatchedBrowserTime: TimeInterval = 0
        let browsers: Set<String> = [
            "Google Chrome", "Safari", "Firefox", "Arc",
            "Brave Browser", "Microsoft Edge", "Orion",
        ]

        for block in scopedBlocks {
            for event in block.events {
                if let device = selectedDevice, event.sourceDevice != device { continue }
                if let site = event.siteName {
                    siteDurations[site, default: 0] += event.duration
                } else if browsers.contains(event.appName) {
                    unmatchedBrowserTime += event.duration
                }
            }
        }

        var results = siteDurations.map { site, duration in
            let mins = Int(duration / 60)
            let tier = ProductivityClassifier.classify(app: "Google Chrome", site: site)
            return (site: site, minutes: mins, tier: tier)
        }
        .filter { $0.minutes > 0 }
        .sorted { $0.minutes > $1.minutes }

        let unmatchedMins = Int(unmatchedBrowserTime / 60)
        if unmatchedMins >= 1 {
            results.append((site: "Other sites", minutes: unmatchedMins, tier: .neutral))
        }

        return results
    }

    var scopedProductivityScore: Int {
        let total = scopedTotalMinutes
        guard total > 0 else { return 0 }
        let deepMins = scopedTierBreakdown.first(where: { $0.tier == .deepWork })?.minutes ?? 0
        let productiveMins = scopedTierBreakdown.first(where: { $0.tier == .productive })?.minutes ?? 0
        let distractMins = scopedTierBreakdown.first(where: { $0.tier == .distraction })?.minutes ?? 0
        let score = Double(deepMins * 100 + productiveMins * 70 + (total - deepMins - productiveMins - distractMins) * 40) / Double(total)
        return min(100, max(0, Int(score)))
    }

    var scopedMacMinutes: Int {
        scopedBlocks.filter { $0.dominantDevice == .mac }.reduce(0) { $0 + $1.durationMinutes }
    }

    var scopedIPhoneMinutes: Int {
        scopedBlocks.filter { $0.dominantDevice == .iphone }.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Pill Minutes (unfiltered by device — always show both device totals)

    private var timeScopedBlocks: [AWActivityBlock] {
        let cal = Calendar.current
        if viewMode == .daily {
            return blocks.filter { cal.isDateInToday($0.start) }
        } else {
            let weekAgo = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date()))!
            return blocks.filter { $0.start >= weekAgo }
        }
    }

    var pillTotalMinutes: Int {
        timeScopedBlocks.reduce(0) { $0 + $1.durationMinutes }
    }
    var pillMacMinutes: Int {
        timeScopedBlocks.filter { $0.dominantDevice == .mac }.reduce(0) { $0 + $1.durationMinutes }
    }
    var pillIPhoneMinutes: Int {
        timeScopedBlocks.filter { $0.dominantDevice == .iphone }.reduce(0) { $0 + $1.durationMinutes }
    }
    var scoreLabel: String {
        let score = scopedProductivityScore
        let period = viewMode == .daily ? "day" : "week"
        switch score {
        case 80...100: return "Highly productive"
        case 60..<80: return "Productive \(period)"
        case 40..<60: return "Mixed focus"
        default: return "Distracted \(period)"
        }
    }
    var scoreSummary: String {
        let breakdown = scopedTierBreakdown
        let deepMins = breakdown.first(where: { $0.tier == .deepWork })?.minutes ?? 0
        let distractMins = breakdown.first(where: { $0.tier == .distraction })?.minutes ?? 0
        if deepMins > 0 && distractMins > 0 {
            return "\(Self.formatMinutes(deepMins)) deep work, \(Self.formatMinutes(distractMins)) distractions"
        } else if deepMins > 0 {
            return "\(Self.formatMinutes(deepMins)) of focused deep work"
        } else {
            return "\(Self.formatMinutes(scopedTotalMinutes)) total screen time"
        }
    }
    static func colorForTier(_ tier: ProductivityTier) -> Color {
        switch tier {
        case .deepWork: return Color(.systemGreen)
        case .productive: return Color(.systemTeal)
        case .neutral: return Color(.systemOrange)
        case .distraction: return Color(.systemRed)
        }
    }

    static func colorForScore(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color(.systemGreen)
        case 60..<80: return Color(.systemTeal)
        case 40..<60: return Color(.systemOrange)
        default: return Color(.systemRed)
        }
    }

    static func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    static func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour == 12 { return "12 PM" }
        if hour < 12 { return "\(hour)" }
        return "\(hour - 12)"
    }
}
