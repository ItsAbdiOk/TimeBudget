import Foundation
import SwiftData

enum DataSource: String, Codable {
    case healthKit
    case coreMotion
    case coreLocation
    case calendar
    case manual
    case aniList
}

@Model
final class TimeEntry {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var sourceRaw: String
    var confidence: Double
    var metadata: [String: String]

    var category: ActivityCategory?

    @Transient
    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    init(
        startDate: Date,
        endDate: Date,
        category: ActivityCategory? = nil,
        source: DataSource,
        confidence: Double = 1.0,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.sourceRaw = source.rawValue
        self.category = category
        self.confidence = confidence
        self.metadata = metadata
    }
}
