import Foundation
import SwiftData

struct Correlation {
    let factorA: String
    let factorB: String
    let coefficient: Double
    let insight: String
    let sampleSize: Int

    var isSignificant: Bool {
        abs(coefficient) >= 0.3 && sampleSize >= 7
    }

    var strengthLabel: String {
        switch abs(coefficient) {
        case 0.7...: return "Strong"
        case 0.5..<0.7: return "Moderate"
        case 0.3..<0.5: return "Mild"
        default: return "Weak"
        }
    }
}

final class CorrelationEngine {
    static let shared = CorrelationEngine()

    /// Compute correlations from daily health snapshots
    func computeCorrelations(snapshots: [HealthSnapshot]) -> [Correlation] {
        guard snapshots.count >= 7 else { return [] }

        var correlations: [Correlation] = []

        // Steps vs Sleep
        let stepsVsSleep = pearson(
            x: snapshots.map { Double($0.steps) },
            y: snapshots.dropFirst().map { Double($0.sleepMinutes) }
        )
        if let r = stepsVsSleep {
            let direction = r > 0 ? "more" : "less"
            correlations.append(Correlation(
                factorA: "Steps",
                factorB: "Next-day Sleep",
                coefficient: r,
                insight: "On days you walk more, you tend to sleep \(direction) the next night",
                sampleSize: snapshots.count - 1
            ))
        }

        // Workout minutes vs Sleep
        let workoutVsSleep = pearson(
            x: snapshots.map { Double($0.workoutMinutes) },
            y: snapshots.dropFirst().map { Double($0.sleepMinutes) }
        )
        if let r = workoutVsSleep {
            let direction = r > 0 ? "better" : "worse"
            correlations.append(Correlation(
                factorA: "Exercise",
                factorB: "Next-day Sleep",
                coefficient: r,
                insight: "Days with more exercise are followed by \(direction) sleep",
                sampleSize: snapshots.count - 1
            ))
        }

        // Sleep vs Next-day Steps
        let sleepVsSteps = pearson(
            x: snapshots.map { Double($0.sleepMinutes) },
            y: snapshots.dropFirst().map { Double($0.steps) }
        )
        if let r = sleepVsSteps {
            let direction = r > 0 ? "more active" : "less active"
            correlations.append(Correlation(
                factorA: "Sleep",
                factorB: "Next-day Activity",
                coefficient: r,
                insight: "After sleeping more, you tend to be \(direction) the next day",
                sampleSize: snapshots.count - 1
            ))
        }

        // Sleep vs Calories
        let sleepVsCal = pearson(
            x: snapshots.map { Double($0.sleepMinutes) },
            y: snapshots.map { $0.activeCalories }
        )
        if let r = sleepVsCal {
            let direction = r > 0 ? "more" : "fewer"
            correlations.append(Correlation(
                factorA: "Sleep",
                factorB: "Calories Burned",
                coefficient: r,
                insight: "On days you sleep more, you burn \(direction) active calories",
                sampleSize: snapshots.count
            ))
        }

        // Steps vs Calories (sanity check — should be strong positive)
        let stepsVsCal = pearson(
            x: snapshots.map { Double($0.steps) },
            y: snapshots.map { $0.activeCalories }
        )
        if let r = stepsVsCal {
            correlations.append(Correlation(
                factorA: "Steps",
                factorB: "Calories",
                coefficient: r,
                insight: "More steps correlate with more calories burned",
                sampleSize: snapshots.count
            ))
        }

        // Return only significant correlations, sorted by strength
        return correlations
            .filter { $0.isSignificant }
            .sorted { abs($0.coefficient) > abs($1.coefficient) }
    }

    /// Compute time fragmentation score for a day's entries
    func fragmentationScore(entries: [TimeEntry]) -> Double {
        guard entries.count > 1 else { return 1.0 }

        let sorted = entries.sorted { $0.startDate < $1.startDate }
        var switches = 0
        for i in 1..<sorted.count {
            if sorted[i].category?.name != sorted[i-1].category?.name {
                switches += 1
            }
        }

        // Normalize: 0 switches = 1.0 (perfect focus), 20+ switches = 0.0 (very fragmented)
        let maxSwitches = 20.0
        return max(0, 1.0 - Double(switches) / maxSwitches)
    }

    // MARK: - Pearson Correlation

    private func pearson(x: [Double], y: [Double]) -> Double? {
        let n = min(x.count, y.count)
        guard n >= 7 else { return nil }

        let xSlice = Array(x.prefix(n))
        let ySlice = Array(y.prefix(n))

        let xMean = xSlice.reduce(0, +) / Double(n)
        let yMean = ySlice.reduce(0, +) / Double(n)

        var numerator = 0.0
        var xDenominator = 0.0
        var yDenominator = 0.0

        for i in 0..<n {
            let xDiff = xSlice[i] - xMean
            let yDiff = ySlice[i] - yMean
            numerator += xDiff * yDiff
            xDenominator += xDiff * xDiff
            yDenominator += yDiff * yDiff
        }

        let denominator = (xDenominator * yDenominator).squareRoot()
        guard denominator > 0 else { return nil }

        return numerator / denominator
    }
}
