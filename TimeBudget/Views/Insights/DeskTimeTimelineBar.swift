import SwiftUI

struct DeskTimeTimelineBar: View {
    let blocks: [AWActivityBlock]
    let hasIPhoneData: Bool

    private var sortedBlocks: [AWActivityBlock] {
        blocks
            .filter { Calendar.current.isDateInToday($0.start) }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        let todayBlocks = sortedBlocks
        if !todayBlocks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S TIMELINE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .tracking(0.5)

                let earliest = todayBlocks.first!.start
                let latest = todayBlocks.last!.end
                let cal = Calendar.current
                let startHour = cal.component(.hour, from: earliest)
                let endHour = min(cal.component(.hour, from: latest) + 1, 24)
                let hourRange = max(endHour - startHour, 1)

                HStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        Text(DeskTimeViewModel.formatHourLabel(hour))
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(Color(.tertiaryLabel))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GeometryReader { geo in
                    let totalSeconds = TimeInterval(hourRange * 3600)
                    let timelineStart = cal.date(bySettingHour: startHour, minute: 0, second: 0, of: Date())!

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(.tertiarySystemFill))

                        ForEach(Array(todayBlocks.enumerated()), id: \.element.id) { _, block in
                            let offset = block.start.timeIntervalSince(timelineStart)
                            let duration = block.end.timeIntervalSince(block.start)
                            let x = max(0, CGFloat(offset / totalSeconds)) * geo.size.width
                            let w = max(3, CGFloat(duration / totalSeconds) * geo.size.width)
                            let tier = ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(DeskTimeViewModel.colorForTier(tier))
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
}

#Preview {
    DeskTimeTimelineBar(
        blocks: DeskTimeMockData.sampleBlocks,
        hasIPhoneData: true
    )
    .padding()
}
