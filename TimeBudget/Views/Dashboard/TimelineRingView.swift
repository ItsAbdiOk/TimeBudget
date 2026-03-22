import SwiftUI

struct TimelineRingView: View {
    let entries: [TimeEntry]
    let date: Date

    private let ringWidth: CGFloat = 24

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color(.tertiarySystemGroupedBackground), lineWidth: ringWidth)

            // Entry arcs
            ForEach(entries, id: \.id) { entry in
                EntryArc(
                    entry: entry,
                    date: date,
                    ringWidth: ringWidth
                )
            }

            // Center content
            VStack(spacing: 4) {
                Text(totalTrackedFormatted)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text("tracked")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(ringWidth / 2 + 4)
        .aspectRatio(1, contentMode: .fit)
    }

    private var totalTrackedFormatted: String {
        let totalMinutes = entries.reduce(0) { $0 + $1.durationMinutes }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return "\(hours)h \(mins)m"
    }
}

struct EntryArc: View {
    let entry: TimeEntry
    let date: Date
    let ringWidth: CGFloat

    var body: some View {
        Circle()
            .trim(from: startFraction, to: endFraction)
            .stroke(
                entry.category?.color ?? .gray,
                style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt)
            )
            .rotationEffect(.degrees(-90))
    }

    private var startFraction: CGFloat {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let secondsFromStart = entry.startDate.timeIntervalSince(startOfDay)
        return CGFloat(max(0, secondsFromStart)) / CGFloat(86400)
    }

    private var endFraction: CGFloat {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let secondsFromStart = entry.endDate.timeIntervalSince(startOfDay)
        return CGFloat(min(86400, secondsFromStart)) / CGFloat(86400)
    }
}

// MARK: - Ring with Labels

struct TimelineRingWithLabels: View {
    let entries: [TimeEntry]
    let date: Date

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                TimelineRingView(entries: entries, date: date)
                    .frame(height: 220)

                // Hour labels
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    HourLabel(hour: hour)
                }
            }
            .frame(height: 240)

            // Legend
            LegendView(entries: entries)
        }
        .card()
    }
}

struct HourLabel: View {
    let hour: Int

    var body: some View {
        let angle = Double(hour) / 24.0 * 360.0 - 90
        let radius: CGFloat = 124

        Text(hourText)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.tertiary)
            .offset(
                x: radius * CGFloat(cos(angle * .pi / 180)),
                y: radius * CGFloat(sin(angle * .pi / 180))
            )
    }

    private var hourText: String {
        switch hour {
        case 0: return "12a"
        case 6: return "6a"
        case 12: return "12p"
        case 18: return "6p"
        default: return "\(hour)"
        }
    }
}

struct LegendView: View {
    let entries: [TimeEntry]

    var body: some View {
        let grouped = Dictionary(grouping: entries) { $0.category?.name ?? "Other" }
        let sorted = grouped.sorted { a, b in
            let aMin = a.value.reduce(0) { $0 + $1.durationMinutes }
            let bMin = b.value.reduce(0) { $0 + $1.durationMinutes }
            return aMin > bMin
        }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(sorted.prefix(6), id: \.key) { name, categoryEntries in
                let totalMin = categoryEntries.reduce(0) { $0 + $1.durationMinutes }
                let color = categoryEntries.first?.category?.color ?? .gray

                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)

                    Text(name)
                        .font(.caption2.weight(.medium))

                    Spacer()

                    Text(formatMinutes(totalMin))
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
