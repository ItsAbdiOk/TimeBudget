import SwiftUI

struct TimelineRingView: View {
    let entries: [TimeEntry]
    let date: Date

    private let ringWidth: CGFloat = 20

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color(.separator), lineWidth: ringWidth)

            // Entry arcs
            ForEach(entries, id: \.id) { entry in
                EntryArc(
                    entry: entry,
                    date: date,
                    ringWidth: ringWidth
                )
            }

            // Hour tick marks — 12 ticks (every 2 hours on 24h clock = every 30 degrees)
            ForEach(0..<12, id: \.self) { index in
                let hour = index * 2
                let isMajor = hour % 6 == 0 // 0, 6, 12, 18 are major
                HourTick(hour: hour, ringRadius: 110, ringWidth: ringWidth, isMajor: isMajor)
            }

            // Now marker
            NowMarker(date: date, ringRadius: 110, ringWidth: ringWidth)

            // Center content
            VStack(spacing: 3) {
                Text(totalTrackedFormatted)
                    .font(.system(size: 26, weight: .semibold))
                    .monospacedDigit()
                Text("TRACKED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .tracking(1.2)
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

// MARK: - Entry Arc

struct EntryArc: View {
    let entry: TimeEntry
    let date: Date
    let ringWidth: CGFloat

    var body: some View {
        Circle()
            .trim(from: startFraction, to: endFraction)
            .stroke(
                entry.category?.color ?? Color(.systemGray),
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

// MARK: - Hour Tick

struct HourTick: View {
    let hour: Int
    let ringRadius: CGFloat
    let ringWidth: CGFloat
    var isMajor: Bool = true

    var body: some View {
        let angle = Double(hour) / 24.0 * 360.0 - 90
        let extension_: CGFloat = isMajor ? 2 : 1
        let innerRadius = ringRadius - ringWidth / 2 - extension_
        let outerRadius = ringRadius + ringWidth / 2 + extension_

        Path { path in
            let startX = outerRadius * CGFloat(cos(angle * .pi / 180))
            let startY = outerRadius * CGFloat(sin(angle * .pi / 180))
            let endX = innerRadius * CGFloat(cos(angle * .pi / 180))
            let endY = innerRadius * CGFloat(sin(angle * .pi / 180))
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        .stroke(Color(.label).opacity(0.15), lineWidth: 1)
        .frame(width: outerRadius * 2, height: outerRadius * 2)
        .offset(x: outerRadius, y: outerRadius)
    }
}

// MARK: - Now Marker

struct NowMarker: View {
    let date: Date
    let ringRadius: CGFloat
    let ringWidth: CGFloat

    var body: some View {
        let fraction = currentTimeFraction
        let angle = fraction * 360.0 - 90
        let markerRadius = ringRadius

        Circle()
            .fill(Color(.systemBlue))
            .frame(width: 8, height: 8)
            .offset(
                x: markerRadius * CGFloat(cos(angle * .pi / 180)),
                y: markerRadius * CGFloat(sin(angle * .pi / 180))
            )
    }

    private var currentTimeFraction: Double {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let secondsFromStart = Date().timeIntervalSince(startOfDay)
        return min(max(secondsFromStart / 86400, 0), 1)
    }
}

// MARK: - Ring with Labels

struct TimelineRingWithLabels: View {
    let entries: [TimeEntry]
    let date: Date

    var body: some View {
        VStack(spacing: 12) {
            // Title row
            HStack {
                Text("24-Hour Ring")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("Today")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            ZStack {
                TimelineRingView(entries: entries, date: date)
                    .frame(height: 220)

                // Hour labels — only 4: 12a, 6a, 12p, 6p
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

// MARK: - Hour Label

struct HourLabel: View {
    let hour: Int

    var body: some View {
        let angle = Double(hour) / 24.0 * 360.0 - 90
        let radius: CGFloat = 124

        Text(hourText)
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(Color(.secondaryLabel))
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

// MARK: - Legend View

struct LegendView: View {
    let entries: [TimeEntry]

    var body: some View {
        let grouped = Dictionary(grouping: entries) { $0.category?.name ?? "Other" }
        let sorted = grouped.sorted { a, b in
            let aMin = a.value.reduce(0) { $0 + $1.durationMinutes }
            let bMin = b.value.reduce(0) { $0 + $1.durationMinutes }
            return aMin > bMin
        }

        FlowLayout(spacing: 12) {
            ForEach(sorted.prefix(6), id: \.key) { name, categoryEntries in
                let color = categoryEntries.first?.category?.color ?? Color(.systemGray)

                HStack(spacing: 5) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)

                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
