import SwiftUI
import Charts

struct TimePieChartView: View {
    let entries: [TimeEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Breakdown")
                .padding(.horizontal, 16)

            if chartData.isEmpty {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "No data yet",
                    subtitle: "Your daily breakdown will appear here"
                )
            } else {
                VStack(spacing: 0) {
                    // Donut chart with center label
                    ZStack {
                        Chart(chartData, id: \.name) { item in
                            SectorMark(
                                angle: .value("Minutes", item.minutes),
                                innerRadius: .ratio(0.62),
                                angularInset: 1.5
                            )
                            .foregroundStyle(item.color)
                            .cornerRadius(4)
                        }
                        .chartLegend(.hidden)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 200)

                        // Center total
                        VStack(spacing: 2) {
                            Text(totalFormatted)
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                            Text("TRACKED")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                                .tracking(0.5)
                        }
                    }
                    .padding(.bottom, 20)

                    // Legend — vertical list, not grid (avoids overlap)
                    VStack(spacing: 10) {
                        ForEach(chartData, id: \.name) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 9, height: 9)

                                Text(item.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color(.label))
                                    .lineLimit(1)

                                Spacer()

                                Text(formatMinutes(item.minutes))
                                    .font(.subheadline.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Color(.secondaryLabel))

                                Text("\(item.percentage)%")
                                    .font(.footnote.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Color(.tertiaryLabel))
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }
                .card()
                .padding(.horizontal, 16)
            }
        }
    }

    private var totalFormatted: String {
        let totalMinutes = entries.reduce(0) { $0 + $1.durationMinutes }
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private var chartData: [PieSlice] {
        let grouped = Dictionary(grouping: entries) { $0.category?.name ?? "Other" }
        let totalMinutes = entries.reduce(0) { $0 + $1.durationMinutes }
        guard totalMinutes > 0 else { return [] }

        return grouped.map { name, categoryEntries in
            let minutes = categoryEntries.reduce(0) { $0 + $1.durationMinutes }
            let color = categoryEntries.first?.category?.color ?? Color(.systemGray)
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
