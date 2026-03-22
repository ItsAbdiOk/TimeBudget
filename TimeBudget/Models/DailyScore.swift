import Foundation
import SwiftData

@Model
final class DailyScore {
    var id: UUID
    var date: Date
    var overallScore: Double
    var categoryScores: [String: Double]
    var totalTrackedMinutes: Int

    init(
        date: Date,
        overallScore: Double,
        categoryScores: [String: Double],
        totalTrackedMinutes: Int
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.overallScore = overallScore
        self.categoryScores = categoryScores
        self.totalTrackedMinutes = totalTrackedMinutes
    }

    var scoreFormatted: String {
        "\(Int(overallScore))"
    }

    var scoreGrade: String {
        switch overallScore {
        case 90...100: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        case 50..<60: return "D"
        default: return "F"
        }
    }

    /// Compute a daily score by comparing actual time entries against ideal day targets
    static func compute(
        entries: [TimeEntry],
        idealTargets: [IdealDay]
    ) -> (overall: Double, perCategory: [String: Double], totalMinutes: Int) {
        guard !idealTargets.isEmpty else {
            return (overall: 0, perCategory: [:], totalMinutes: 0)
        }

        // Sum actual minutes per category
        var actualMinutes: [String: Int] = [:]
        var totalMinutes = 0
        for entry in entries {
            let name = entry.category?.name ?? "Other"
            let minutes = entry.durationMinutes
            actualMinutes[name, default: 0] += minutes
            totalMinutes += minutes
        }

        // Score each category: min(actual/target, 1.0) * 100
        var categoryScores: [String: Double] = [:]
        var totalWeight = 0.0
        var weightedSum = 0.0

        for target in idealTargets where target.targetMinutes > 0 {
            let actual = Double(actualMinutes[target.categoryName] ?? 0)
            let goal = Double(target.targetMinutes)
            let ratio = min(actual / goal, 1.5) // Cap at 150% to not over-reward
            let score = min(ratio * 100, 100)
            categoryScores[target.categoryName] = score

            // Weight by target size (bigger goals matter more)
            let weight = goal
            weightedSum += score * weight
            totalWeight += weight
        }

        let overall = totalWeight > 0 ? weightedSum / totalWeight : 0
        return (overall: overall, perCategory: categoryScores, totalMinutes: totalMinutes)
    }
}
