import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var isRunning: Bool
    var categoryName: String

    var duration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    var durationFormatted: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    init(categoryName: String) {
        self.id = UUID()
        self.startDate = Date()
        self.endDate = nil
        self.isRunning = true
        self.categoryName = categoryName
    }

    func stop() {
        self.endDate = Date()
        self.isRunning = false
    }
}
