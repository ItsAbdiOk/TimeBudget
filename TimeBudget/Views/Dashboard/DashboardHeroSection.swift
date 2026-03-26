import SwiftUI

// MARK: - Greeting Hero

struct GreetingHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date line
            Text(dateString.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color(.tertiaryLabel))

            // Greeting with bold name
            (Text(greetingPrefix + ",\n")
                .font(.system(size: 34, weight: .bold))
             + Text("Abdi.")
                .font(.system(size: 34, weight: .heavy)))
                .tracking(-0.4)
                .lineSpacing(2)

            // Contextual subtitle
            Text(subtitleText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }

    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<5: return "Late night"
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    private var subtitleText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        // Contextual deep work hint based on time of day
        if hour < 9 {
            let minsUntilNine = (9 - hour) * 60 - minute
            return "Your deep work window opens in \(minsUntilNine) minutes."
        } else if hour < 12 {
            return "You're in your peak focus window right now."
        } else if hour < 17 {
            return "Afternoon — a great time for lighter tasks."
        } else {
            return "Wind down and review your day."
        }
    }
}

// MARK: - Score Hero Card

struct ScoreHeroCard: View {
    let score: DailyScore
    let entries: [TimeEntry]

    private var gradeColor: Color {
        switch score.overallScore {
        case 80...100: return Color(.systemGreen)
        case 60..<80: return Color(.systemOrange)
        default: return Color(.systemRed)
        }
    }

    private var gradeTag: String {
        switch score.overallScore {
        case 90...100: return "CRUSHING IT"
        case 80..<90: return "ON TRACK"
        case 70..<80: return "SOLID"
        case 55..<70: return "STEADY"
        default: return "WARMING UP"
        }
    }

    private var headlineText: AttributedString {
        let label: String
        switch score.overallScore {
        case 85...100: label = "An **excellent day.**"
        case 70..<85: label = "A **solid day.**"
        case 55..<70: label = "A **steady day.**"
        default: label = "A **slow start.**"
        }
        return (try? AttributedString(markdown: label)) ?? AttributedString(label)
    }

    private var descriptionText: String {
        let tracked = score.totalTrackedMinutes
        let hours = tracked / 60
        let mins = tracked % 60
        if hours > 0 {
            return "You've tracked \(hours)h \(mins)m across \(categoryPills.count) categories so far today."
        }
        return "You've tracked \(mins)m across \(categoryPills.count) categories so far today."
    }

    private var categoryPills: [(name: String, color: Color)] {
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
        HStack(alignment: .top, spacing: 18) {
            // Ring with score
            VStack(spacing: 6) {
                CircularProgress(
                    progress: score.overallScore / 100.0,
                    lineWidth: 8,
                    color: gradeColor,
                    showLabel: false
                )
                .frame(width: 68, height: 68)
                .overlay {
                    Text(score.scoreFormatted)
                        .font(.system(size: 26, weight: .semibold))
                        .monospacedDigit()
                }

                Text(gradeTag)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(gradeColor)
            }

            // Right side: headline + description + pills
            VStack(alignment: .leading, spacing: 8) {
                Text(headlineText)
                    .font(.system(size: 20, weight: .semibold))

                Text(descriptionText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(3)

                // Category pills
                FlowLayout(spacing: 6) {
                    ForEach(categoryPills, id: \.name) { pill in
                        CategoryPill(name: pill.name, color: pill.color)
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .heroCard()
    }
}

// MARK: - Previews

#Preview("Greeting Hero") {
    GreetingHero()
        .padding()
}
