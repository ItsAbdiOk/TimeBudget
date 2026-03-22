import SwiftUI

/// Apple-style contribution calendar. Auto-sizes cells to fill available width.
struct ContributionCalendarView: View {
    let data: [Date: Double]
    let accentColor: Color
    let weeks: Int

    init(data: [Date: Double], accentColor: Color, weeks: Int = 13) {
        self.data = data
        self.accentColor = accentColor
        self.weeks = weeks
    }

    init(data: [Date: Int], accentColor: Color, weeks: Int = 13) {
        self.data = data.mapValues { Double($0) }
        self.accentColor = accentColor
        self.weeks = weeks
    }

    private let dayLabels = ["M", "", "W", "", "F", "", ""]
    private let labelWidth: CGFloat = 20
    private let spacing: CGFloat = 3
    private let cornerRadius: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - labelWidth - spacing
            let cellSize = max((availableWidth - spacing * CGFloat(weeks - 1)) / CGFloat(weeks), 8)
            let grid = buildGrid()
            let maxVal = max(data.values.max() ?? 1, 1)
            let months = buildMonthLabels()

            VStack(alignment: .leading, spacing: 6) {
                // Month labels
                HStack(spacing: 0) {
                    Spacer().frame(width: labelWidth + spacing)
                    ForEach(months, id: \.offset) { month in
                        Text(month.label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: CGFloat(month.span) * (cellSize + spacing), alignment: .leading)
                    }
                    Spacer(minLength: 0)
                }

                HStack(alignment: .top, spacing: spacing) {
                    // Day labels
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { day in
                            Text(dayLabels[day])
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .frame(width: labelWidth, height: cellSize)
                        }
                    }

                    // Week columns
                    ForEach(0..<weeks, id: \.self) { week in
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { day in
                                let info = grid[week][day]
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .fill(info.isFuture ? Color.clear : cellColor(value: info.value, maxVal: maxVal))
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }

                // Legend
                HStack(spacing: 5) {
                    Spacer()
                    Text("Less")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                    ForEach(0..<5, id: \.self) { i in
                        let intensity = Double(i) / 4.0
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(i == 0 ? Color(.tertiarySystemFill) : accentColor.opacity(0.2 + intensity * 0.6))
                            .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                    }
                    Text("More")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
        .frame(height: calculateHeight())
    }

    private func calculateHeight() -> CGFloat {
        // Estimate: assume ~320pt available width for cell sizing
        let estimatedCellSize: CGFloat = 20
        let monthRow: CGFloat = 16
        let legendRow: CGFloat = 20
        return monthRow + 6 + (estimatedCellSize + spacing) * 7 + 6 + legendRow
    }

    private func cellColor(value: Double, maxVal: Double) -> Color {
        if value == 0 { return Color(.tertiarySystemFill) }
        let intensity = value / maxVal
        return accentColor.opacity(0.2 + intensity * 0.6)
    }

    private struct CellInfo {
        let value: Double
        let isFuture: Bool
    }

    private func buildGrid() -> [[CellInfo]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today)
        let todayDayIndex = (todayWeekday + 5) % 7

        var grid = Array(repeating: Array(repeating: CellInfo(value: 0, isFuture: true), count: 7), count: weeks)

        for week in 0..<weeks {
            for day in 0..<7 {
                let weeksBack = weeks - 1 - week
                let daysFromEndOfWeek = 6 - todayDayIndex
                let totalDaysBack = weeksBack * 7 + (6 - day) - daysFromEndOfWeek

                guard let date = calendar.date(byAdding: .day, value: -totalDaysBack, to: today) else { continue }
                let startOfDay = calendar.startOfDay(for: date)

                if startOfDay > today {
                    grid[week][day] = CellInfo(value: 0, isFuture: true)
                } else {
                    grid[week][day] = CellInfo(value: data[startOfDay] ?? 0, isFuture: false)
                }
            }
        }

        return grid
    }

    private struct MonthLabel: Hashable {
        let label: String
        let span: Int
        let offset: Int
    }

    private func buildMonthLabels() -> [MonthLabel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayDayIndex = (calendar.component(.weekday, from: today) + 5) % 7
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var labels: [MonthLabel] = []
        var currentMonth = -1
        var currentSpan = 0
        var labelStart = 0

        for week in 0..<weeks {
            let weeksBack = weeks - 1 - week
            let daysFromEndOfWeek = 6 - todayDayIndex
            let totalDaysBack = weeksBack * 7 + 6 - daysFromEndOfWeek

            guard let date = calendar.date(byAdding: .day, value: -totalDaysBack, to: today) else { continue }
            let month = calendar.component(.month, from: date)

            if month != currentMonth {
                if currentSpan > 0 {
                    let monthDate = calendar.date(byAdding: .day, value: -(weeks - 1 - labelStart) * 7 + (6 - todayDayIndex), to: today) ?? today
                    labels.append(MonthLabel(
                        label: formatter.string(from: monthDate),
                        span: currentSpan,
                        offset: labelStart
                    ))
                }
                currentMonth = month
                currentSpan = 1
                labelStart = week
            } else {
                currentSpan += 1
            }
        }

        if currentSpan > 0 {
            let monthDate = calendar.date(byAdding: .day, value: -(weeks - 1 - labelStart) * 7 + (6 - todayDayIndex), to: today) ?? today
            labels.append(MonthLabel(
                label: formatter.string(from: monthDate),
                span: currentSpan,
                offset: labelStart
            ))
        }

        return labels
    }
}
