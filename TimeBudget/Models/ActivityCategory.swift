import Foundation
import SwiftUI
import SwiftData

@Model
final class ActivityCategory {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var isSystem: Bool
    var sortOrder: Int

    @Relationship(inverse: \TimeEntry.category)
    var entries: [TimeEntry] = []

    var color: Color {
        Color(hex: colorHex)
    }

    init(name: String, icon: String, colorHex: String, isSystem: Bool = true, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isSystem = isSystem
        self.sortOrder = sortOrder
    }

    static func seedDefaults(into context: ModelContext) {
        let defaults: [(String, String, String, Int)] = [
            ("Sleep", "moon.fill", "#5E5CE6", 0),
            ("Exercise", "figure.run", "#30D158", 1),
            ("Walking", "figure.walk", "#64D2FF", 2),
            ("Running", "figure.run", "#FF9F0A", 3),
            ("Cycling", "bicycle", "#FFD60A", 4),
            ("Commute", "car.fill", "#FF6482", 5),
            ("Work", "briefcase.fill", "#0A84FF", 6),
            ("Meetings", "person.2.fill", "#BF5AF2", 7),
            ("Deep Work", "brain.head.profile", "#FF375F", 8),
            ("Reading", "book.fill", "#AC8E68", 9),
            ("Creative", "paintbrush.fill", "#FF9F0A", 10),
            ("Podcast", "headphones", "#F43F5E", 11),
            ("Desk Time", "desktopcomputer", "#8B5CF6", 12),
            ("Stationary", "figure.stand", "#8E8E93", 13),
            ("Other", "questionmark.circle", "#636366", 14),
        ]

        for (name, icon, color, order) in defaults {
            let category = ActivityCategory(name: name, icon: icon, colorHex: color, sortOrder: order)
            context.insert(category)
        }
    }
}
