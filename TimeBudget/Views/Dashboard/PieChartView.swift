import SwiftUI
import Charts

struct TimePieChartView: View {
    let entries: [TimeEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Where Did My Day Go?")
                .padding(.horizontal, 16)

            if chartData.isEmpty {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "No data yet",
                    subtitle: "Your daily breakdown will appear here"
                )
            } else {
                VStack(spacing: 16) {
                    Chart(chartData, id: \.name) { item in
                        SectorMark(
                            angle: .value("Minutes", item.minutes),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(5)
                    }
                    .frame(height: 200)

                    // Labels
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(chartData, id: \.name) { item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)

                                Text(item.name)
                                    .font(.caption.weight(.medium))

                                Spacer()

                                Text("\(item.percentage)%")
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .card()
                .padding(.horizontal, 16)
            }
        }
    }

    private var chartData: [PieSlice] {
        let grouped = Dictionary(grouping: entries) { $0.category?.name ?? "Other" }
        let totalMinutes = entries.reduce(0) { $0 + $1.durationMinutes }
        guard totalMinutes > 0 else { return [] }

        return grouped.map { name, categoryEntries in
            let minutes = categoryEntries.reduce(0) { $0 + $1.durationMinutes }
            let color = categoryEntries.first?.category?.color ?? .gray
            let percentage = Int(Double(minutes) / Double(totalMinutes) * 100)
            return PieSlice(name: name, minutes: minutes, percentage: percentage, color: color)
        }
        .sorted { $0.minutes > $1.minutes }
    }
}

struct PieSlice {
    let name: String
    let minutes: Int
    let percentage: Int
    let color: Color
}
