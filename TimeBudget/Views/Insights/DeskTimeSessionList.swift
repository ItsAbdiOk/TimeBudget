import SwiftUI

struct DeskTimeSessionList: View {
    let blocks: [AWActivityBlock]
    let aiRefinedCount: Int
    let viewMode: DeskTimeViewModel.ViewMode
    let hasIPhoneData: Bool

    /// Merge consecutive blocks with the same top app within 15 minutes of each other,
    /// then filter out very short sessions (< 3 minutes) to reduce clutter.
    private var mergedBlocks: [AWActivityBlock] {
        let sorted = blocks.sorted { $0.start < $1.start }
        guard !sorted.isEmpty else { return [] }

        var merged: [AWActivityBlock] = []
        var current = sorted[0]

        for next in sorted.dropFirst() {
            let sameApp = current.topApp == next.topApp
            let gap = next.start.timeIntervalSince(current.end)

            if sameApp && gap < 15 * 60 {
                current = AWActivityBlock(
                    start: current.start,
                    end: next.end,
                    category: current.category,
                    topApp: current.topApp,
                    topSite: current.topSite ?? next.topSite,
                    events: current.events + next.events,
                    aiCategory: current.aiCategory
                )
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)

        return merged
            .filter { $0.durationMinutes >= 3 }
            .sorted { $0.start > $1.start }
    }

    var body: some View {
        let sorted = mergedBlocks
        if !sorted.isEmpty {
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

                ForEach(Array(sorted.prefix(viewMode == .daily ? 50 : 20).enumerated()), id: \.element.id) { index, block in
                    if index > 0 { Divider() }
                    sessionRow(block: block)
                }
            }
            .card()
        }
    }

    /// Extract the most-watched video/page title from a block's events (for YouTube, etc.)
    private func topContentTitle(for block: AWActivityBlock) -> String? {
        let videoSites: Set<String> = ["youtube.com", "twitch.tv", "netflix.com"]
        guard let site = block.topSite, videoSites.contains(site) else { return nil }

        // Find the longest-duration event with a meaningful title
        let candidates = block.events
            .filter { $0.siteName == site && !$0.windowTitle.isEmpty }
            .sorted { $0.duration > $1.duration }

        guard let top = candidates.first else { return nil }
        // Strip common suffixes like " - YouTube", " - Twitch"
        let title = top.windowTitle
            .replacingOccurrences(of: " - YouTube", with: "")
            .replacingOccurrences(of: " - Twitch", with: "")
            .replacingOccurrences(of: " - Netflix", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private func sessionRow(block: AWActivityBlock) -> some View {
        let contentTitle = topContentTitle(for: block)

        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(DeskTimeViewModel.colorForTier(ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral))
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(contentTitle ?? block.topSite ?? block.topApp)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    if block.isAIRefined {
                        Image(systemName: "brain")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(.systemPurple))
                    }
                }
                HStack(spacing: 5) {
                    if contentTitle != nil || block.topSite != nil {
                        Text(contentTitle != nil ? (block.topSite ?? block.topApp) : block.topApp)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
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

                    Text("\(DeskTimeViewModel.formatTime(block.start))–\(DeskTimeViewModel.formatTime(block.end))")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(DeskTimeViewModel.formatMinutes(block.durationMinutes))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                if block.isAIRefined {
                    Text(block.effectiveCategory)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(.systemPurple))
                } else {
                    Text(block.effectiveCategory)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DeskTimeViewModel.colorForTier(ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral))
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    DeskTimeSessionList(
        blocks: DeskTimeMockData.sampleBlocks,
        aiRefinedCount: 2,
        viewMode: .daily,
        hasIPhoneData: true
    )
    .padding()
}
