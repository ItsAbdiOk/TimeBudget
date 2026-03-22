import Foundation
import SwiftData

@Model
final class HealthSnapshot {
    var id: UUID
    var date: Date
    var steps: Int
    var activeCalories: Double
    var sleepMinutes: Int
    var sleepQuality: Double?
    var restingHeartRate: Double?
    var hrv: Double?
    var workoutMinutes: Int
    var workoutCount: Int

    init(
        date: Date,
        steps: Int = 0,
        activeCalories: Double = 0,
        sleepMinutes: Int = 0,
        sleepQuality: Double? = nil,
        restingHeartRate: Double? = nil,
        hrv: Double? = nil,
        workoutMinutes: Int = 0,
        workoutCount: Int = 0
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.steps = steps
        self.activeCalories = activeCalories
        self.sleepMinutes = sleepMinutes
        self.sleepQuality = sleepQuality
        self.restingHeartRate = restingHeartRate
        self.hrv = hrv
        self.workoutMinutes = workoutMinutes
        self.workoutCount = workoutCount
    }
}
