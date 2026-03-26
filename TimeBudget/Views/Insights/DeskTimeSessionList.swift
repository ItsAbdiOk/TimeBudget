import SwiftUI

struct DeskTimeSessionList: View {
    let blocks: [AWActivityBlock]
    let aiRefinedCount: Int
    let viewMode: DeskTimeViewModel.ViewMode
    let hasIPhoneData: Bool

    private var sessionBlocks: [AWActivityBlock] {
        blocks.sorted { $0.start > $1.start }
    }

    var body: some View {
        let sorted = sessionBlocks
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

    private func sessionRow(block: AWActivityBlock) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(DeskTimeViewModel.colorForTier(ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral))
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
