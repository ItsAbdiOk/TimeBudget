import SwiftUI

// MARK: - Timeline Section

struct TimelineSection: View {
    let entries: [TimeEntry]

    private var sortedEntries: [TimeEntry] {
        entries
            .filter { $0.category?.name != "Stationary" }
            .sorted { $0.startDate < $1.startDate }
    }

    private var totalDuration: Double {
        entries.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title
            HStack {
                Text("Timeline")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("See all")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.systemBlue))
            }

            // Horizontal stacked bar
            if totalDuration > 0 {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(sortedEntries, id: \.id) { entry in
                            let proportion = entry.duration / totalDuration
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(entry.category?.color ?? Color(.systemGray))
                                .frame(width: max(geo.size.width * proportion - 1, 2))
                        }
                    }
                }
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }

            // All rows in one grouped card
            VStack(spacing: 0) {
                ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 18)
                    }
                    TimelineRow(entry: entry)
                }
            }
            .card(padding: 0)
        }
    }
}

#Preview("Timeline Section") {
    TimelineSection(entries: [])
        .padding()
}
