import Foundation
import SwiftData

/// The entry tuple type used across all TimeClassifier files.
typealias ClassifiedEntry = (start: Date, end: Date, category: String, source: DataSource, confidence: Double, metadata: [String: String])

@Observable
final class TimeClassifier {
    static let shared = TimeClassifier()

    let healthKit = HealthKitService.shared
    let motion = MotionService.shared
    let calendar = CalendarService.shared
    let location = LocationService.shared
    let aniList = AniListService.shared
    let pocketCasts = PocketCastsService.shared
    let activityWatch = ActivityWatchService.shared

    /// Priority order for resolving overlaps:
    /// 1. Manual (focus sessions) — highest
    /// 2. HealthKit sleep
    /// 3. HealthKit workouts
    /// 4. Calendar events
    /// 5. Core Motion + Location — lowest

    func classifyDay(date: Date, context: ModelContext) async throws {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Remove old auto-generated entries for this day (keep manual entries)
        let manualSource = DataSource.manual.rawValue
        let existingDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startDate >= startOfDay && entry.startDate < endOfDay && entry.sourceRaw != manualSource
            }
        )
        let existing = (try? context.fetch(existingDescriptor)) ?? []
        for entry in existing {
            context.delete(entry)
        }

        // Fetch categories
        let categoryDescriptor = FetchDescriptor<ActivityCategory>()
        let categories = (try? context.fetch(categoryDescriptor)) ?? []
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0) })

        // Collect entries from all sources (in priority order)
        var entries = await collectEntries(date: date, startOfDay: startOfDay, endOfDay: endOfDay, categoryMap: categoryMap, context: context)

        // Resolve overlaps: higher priority entries mask lower priority ones
        let resolvedEntries: [ClassifiedEntry]
        if #available(iOS 26, *),
           UserDefaults.standard.bool(forKey: "intelligence_conflicts_enabled") {
            resolvedEntries = await resolveOverlapsWithIntelligence(entries)
        } else {
            resolvedEntries = resolveOverlaps(entries)
        }

        // Insert resolved entries
        for entry in resolvedEntries {
            let timeEntry = TimeEntry(
                startDate: entry.start,
                endDate: entry.end,
                category: categoryMap[entry.category] ?? categoryMap["Other"],
                source: entry.source,
                confidence: entry.confidence,
                metadata: entry.metadata
            )
            context.insert(timeEntry)
        }

        // Update daily snapshot
        try await updateSnapshot(for: date, context: context)

        try context.save()
    }
}
