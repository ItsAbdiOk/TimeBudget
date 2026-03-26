import SwiftUI

// MARK: - Timeline Row

struct TimelineRow: View {
    let entry: TimeEntry

    private var timeRange: String {
        let start = entry.startDate.formatted(date: .omitted, time: .shortened)
        let end = entry.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start)\u{2013}\(end)"
    }

    private var isAW: Bool { entry.sourceRaw == "activityWatch" }
    private var isAIRefined: Bool { entry.metadata["aiRefined"] == "true" }

    var body: some View {
        HStack(spacing: 10) {
            // Color stripe
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(entry.category?.color ?? Color(.systemGray))
                .frame(width: 3, height: 40)

            // Name + meta
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(entry.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    if isAIRefined {
                        Image(systemName: "brain")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(.systemPurple))
                    }
                }
                HStack(spacing: 5) {
                    // Category badge for all entries
                    if let categoryName = entry.category?.name {
                        Text(categoryName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isAIRefined ? Color(.systemPurple) : (entry.category?.color ?? Color(.secondaryLabel)))
                    }
                    Text(timeRange)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Spacer()

            // Duration right-aligned
            Text(entry.durationFormatted)
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color(.label))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#Preview("Timeline Row") {
    TimelineRow(entry: TimeEntry(
        startDate: Date().addingTimeInterval(-3600),
        endDate: Date(),
        source: .healthKit
    ))
    .padding()
}
