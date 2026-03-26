import SwiftUI

// MARK: - 24-Hour Ring Card

struct DayRingCard: View {
    let entries: [TimeEntry]

    private var totalTracked: String {
        let total = entries.reduce(0) { $0 + $1.durationMinutes }
        let h = total / 60
        let m = total % 60
        return "\(h)h \(m)m"
    }

    private var legendItems: [(name: String, color: Color)] {
        var seen = Set<String>()
        var result: [(name: String, color: Color)] = []
        for entry in entries {
            let name = entry.category?.name ?? "Other"
            if seen.insert(name).inserted {
                result.append((name: name, color: entry.category?.color ?? Color(.systemGray)))
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 16) {
            // Title row
            HStack {
                Text("24-Hour Ring")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("Today")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            // Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 20)

                // Hour tick marks (every 30 degrees = 12 ticks)
                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) * 30.0
                    Rectangle()
                        .fill(Color(.tertiaryLabel))
                        .frame(width: 1, height: 8)
                        .offset(y: -85)
                        .rotationEffect(.degrees(angle))
                }

                // Entry arcs
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    let startAngle = angleForTime(entry.startDate)
                    let endAngle = angleForTime(entry.endDate)
                    Circle()
                        .trim(from: normalizeAngle(startAngle), to: normalizeAngle(endAngle))
                        .stroke(
                            entry.category?.color ?? Color(.systemGray),
                            style: StrokeStyle(lineWidth: 20, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                }

                // Center label
                VStack(spacing: 2) {
                    Text(totalTracked)
                        .font(.system(size: 26, weight: .semibold))
                        .monospacedDigit()
                    Text("TRACKED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .frame(width: 190, height: 190)

            // Legend
            FlowLayout(spacing: 12) {
                ForEach(legendItems, id: \.name) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 6, height: 6)
                        Text(item.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }
        }
        .card()
    }

    private func angleForTime(_ date: Date) -> Double {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        return (Double(hour) + Double(minute) / 60.0) / 24.0 * 360.0
    }

    private func normalizeAngle(_ degrees: Double) -> CGFloat {
        CGFloat(degrees / 360.0)
    }
}

#Preview("Day Ring Card") {
    DayRingCard(entries: [])
        .padding()
}
