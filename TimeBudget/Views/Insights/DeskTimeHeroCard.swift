import SwiftUI

struct DeskTimeHeroCard: View {
    let score: Int
    let scoreLabel: String
    let scoreSummary: String
    let scoreColor: Color

    var body: some View {
        HStack(spacing: 18) {
            CircularProgress(
                progress: Double(score) / 100.0,
                lineWidth: 8,
                color: scoreColor,
                showLabel: false
            )
            .frame(width: 68, height: 68)
            .overlay {
                Text("\(score)")
                    .font(.system(size: 26, weight: .semibold))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("PRODUCTIVITY SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color(.secondaryLabel))

                Text(scoreLabel)
                    .font(.system(size: 20, weight: .semibold))

                Text(scoreSummary)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .heroCard()
    }
}

#Preview {
    DeskTimeHeroCard(
        score: 72,
        scoreLabel: "Productive day",
        scoreSummary: "2h 15m deep work, 45m distractions",
        scoreColor: .green
    )
    .padding()
}
