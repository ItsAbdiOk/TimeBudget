import SwiftUI

// MARK: - Insight Card

struct DashboardInsightCard: View {
    let entries: [TimeEntry]

    private var insightText: String {
        let total = entries.reduce(0) { $0 + $1.durationMinutes }
        if total > 360 {
            return "You've been highly active today with over \(total / 60) hours tracked. Consider scheduling a break."
        } else if total > 120 {
            return "Solid tracking today. Your most active category is building good momentum."
        } else {
            return "Your day is just getting started. Morning routines set the tone for deep focus later."
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon box
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBlue).opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(.systemBlue))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S INSIGHT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color(.systemBlue))

                Text(insightText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBlue).opacity(0.09),
                    Color(.systemGreen).opacity(0.06)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemBlue).opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview("Insight Card") {
    DashboardInsightCard(entries: [])
        .padding()
}
