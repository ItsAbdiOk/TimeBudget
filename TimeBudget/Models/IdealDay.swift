import Foundation
import SwiftData

@Model
final class IdealDay {
    var id: UUID
    var categoryName: String
    var targetMinutes: Int

    init(categoryName: String, targetMinutes: Int) {
        self.id = UUID()
        self.categoryName = categoryName
        self.targetMinutes = targetMinutes
    }

    var targetFormatted: String {
        let hours = targetMinutes / 60
        let mins = targetMinutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
    }
}
