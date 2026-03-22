import Foundation
import SwiftData

@Model
final class TimeBudgetModel {
    var id: UUID
    var categoryName: String
    var targetMinutesPerDay: Int
    var allowRollover: Bool
    var rolloverMinutes: Int
    var isActive: Bool

    init(
        categoryName: String,
        targetMinutesPerDay: Int,
        allowRollover: Bool = false,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.categoryName = categoryName
        self.targetMinutesPerDay = targetMinutesPerDay
        self.allowRollover = allowRollover
        self.rolloverMinutes = 0
        self.isActive = isActive
    }

    var targetFormatted: String {
        let hours = targetMinutesPerDay / 60
        let mins = targetMinutesPerDay % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
    }

    /// Effective budget including rollover
    var effectiveMinutes: Int {
        targetMinutesPerDay + (allowRollover ? rolloverMinutes : 0)
    }

    /// Calculate progress (0.0 to 1.0+) given actual minutes
    func progress(actualMinutes: Int) -> Double {
        guard effectiveMinutes > 0 else { return 0 }
        return Double(actualMinutes) / Double(effectiveMinutes)
    }

    /// Update rollover based on today's actual usage
    func updateRollover(actualMinutes: Int) {
        guard allowRollover else { return }
        let unused = targetMinutesPerDay - actualMinutes
        if unused > 0 {
            rolloverMinutes += unused
        } else {
            // Used more than budget — reduce rollover
            rolloverMinutes = max(0, rolloverMinutes + unused)
        }
    }
}
