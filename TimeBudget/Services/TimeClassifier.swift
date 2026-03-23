import Foundation
import SwiftData

@Observable
final class TimeClassifier {
    static let shared = TimeClassifier()

    private let healthKit = HealthKitService.shared
    private let motion = MotionService.shared
    private let calendar = CalendarService.shared
    private let location = LocationService.shared
    private let aniList = AniListService.shared
    private let pocketCasts = PocketCastsService.shared
    private let activityWatch = ActivityWatchService.shared

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
        var entries: [(start: Date, end: Date, category: String, source: DataSource, confidence: Double, metadata: [String: String])] = []

        // 1. HealthKit sleep (priority 2) — merge stages, detect Fajr prayer
        let sleepSamples = (try? await healthKit.fetchSleepSamples(for: date)) ?? []
        let allSleepSorted = sleepSamples.sorted { $0.startDate < $1.startDate }
        let sleepOnly = allSleepSorted.filter { $0.stage != .awake }
        let awakePeriods = allSleepSorted.filter { $0.stage == .awake }
        let mergedSleep = mergeSleepSamples(sleepOnly)
        for block in mergedSleep {
            entries.append((
                start: block.start,
                end: block.end,
                category: "Sleep",
                source: .healthKit,
                confidence: 0.95,
                metadata: ["sleepStage": "merged"]
            ))
        }

        // Detect Fajr prayer: awake period >= 35 minutes during a sleep session
        let fajrEntries = detectFajrPrayer(awakePeriods: awakePeriods, sleepBlocks: mergedSleep)
        for fajr in fajrEntries {
            entries.append((
                start: fajr.start,
                end: fajr.end,
                category: "Fajr",
                source: .healthKit,
                confidence: 0.85,
                metadata: ["detected": "awake-during-sleep"]
            ))
        }

        // 2. HealthKit workouts (priority 3)
        let workouts = (try? await healthKit.fetchWorkouts(for: date)) ?? []
        for workout in workouts {
            entries.append((
                start: workout.startDate,
                end: workout.endDate,
                category: workoutCategoryName(for: workout),
                source: .healthKit,
                confidence: 0.9,
                metadata: ["workoutType": workout.name, "calories": String(format: "%.0f", workout.totalCalories)]
            ))
        }

        // 3. Calendar events (priority 4)
        let calendarEvents = calendar.fetchEvents(for: date)
        for event in calendarEvents {
            entries.append((
                start: event.startDate,
                end: event.endDate,
                category: "Meetings",
                source: .calendar,
                confidence: 0.85,
                metadata: ["title": event.title, "calendar": event.calendarName]
            ))
        }

        // 4. AniList manga reading (priority 4, same as calendar)
        // Uses cached data — sync happens on pull-to-refresh or BGAppRefreshTask, not here
        let readingActivities = aniList.cachedReadingActivity(for: date)
        for activity in readingActivities {
            let readingMinutes = activity.chaptersRead * aniList.minutesPerChapter
            let readingEnd = activity.createdAt
            let readingStart = readingEnd.addingTimeInterval(-Double(readingMinutes * 60))
            entries.append((
                start: readingStart,
                end: readingEnd,
                category: "Reading",
                source: .aniList,
                confidence: 0.85,
                metadata: ["title": activity.mediaTitle, "chapters": "\(activity.chaptersRead)", "source": "AniList"]
            ))
        }

        // 5. Pocket Casts podcast listening (priority 4, same as calendar/AniList)
        if pocketCasts.isConfigured {
            let episodes = (try? await pocketCasts.fetchTodayEpisodes()) ?? []
            for episode in episodes {
                guard let playedAt = episode.lastPlayedAt else { continue }
                let listenDuration = TimeInterval(episode.listenedMinutes * 60)
                let listenStart = playedAt.addingTimeInterval(-listenDuration)
                entries.append((
                    start: listenStart,
                    end: playedAt,
                    category: "Podcast",
                    source: .pocketCasts,
                    confidence: 0.85,
                    metadata: [
                        "title": episode.title,
                        "podcast": episode.podcastTitle,
                        "source": "PocketCasts"
                    ]
                ))
            }
        }

        // 6. ActivityWatch desktop activity (priority 4)
        if activityWatch.isConfigured {
            let blocks = (try? await activityWatch.fetchBlocks(for: date)) ?? []
            for block in blocks {
                entries.append((
                    start: block.start,
                    end: block.end,
                    category: block.category,
                    source: .activityWatch,
                    confidence: 0.8,
                    metadata: [
                        "topApp": block.topApp,
                        "source": "ActivityWatch"
                    ]
                ))
            }
        }

        // 7. Core Motion activities (lowest priority)
        let motionSegments = (try? await motion.fetchActivities(from: startOfDay, to: min(endOfDay, Date()))) ?? []
        for segment in motionSegments {
            let categoryName = motionCategoryName(for: segment, context: context)
            entries.append((
                start: segment.startDate,
                end: segment.endDate,
                category: categoryName,
                source: .coreMotion,
                confidence: segment.confidence * 0.8,
                metadata: ["motionType": segment.activity.rawValue]
            ))
        }

        // Resolve overlaps: higher priority entries mask lower priority ones
        let resolvedEntries = resolveOverlaps(entries)

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

    // MARK: - Overlap Resolution

    private func resolveOverlaps(
        _ entries: [(start: Date, end: Date, category: String, source: DataSource, confidence: Double, metadata: [String: String])]
    ) -> [(start: Date, end: Date, category: String, source: DataSource, confidence: Double, metadata: [String: String])] {

        // Source priority (lower number = higher priority)
        func priority(for source: DataSource, category: String) -> Int {
            switch source {
            case .manual: return 0
            case .healthKit where category == "Sleep": return 1
            case .healthKit: return 2
            case .calendar: return 3
            case .aniList: return 4
            case .pocketCasts: return 4
            case .activityWatch: return 4
            case .coreMotion: return 5
            case .coreLocation: return 6
            }
        }

        // Sort by priority (highest first)
        let sorted = entries.sorted { priority(for: $0.source, category: $0.category) < priority(for: $1.source, category: $1.category) }

        var occupied: [(start: Date, end: Date)] = []

        // For each entry (highest priority first), mark its time as occupied
        // Lower priority entries that overlap get trimmed or removed
        var finalEntries: [(start: Date, end: Date, category: String, source: DataSource, confidence: Double, metadata: [String: String])] = []

        for entry in sorted {
            var remainingSegments = [(start: entry.start, end: entry.end)]

            for occ in occupied {
                var newSegments: [(start: Date, end: Date)] = []
                for seg in remainingSegments {
                    // No overlap
                    if seg.end <= occ.start || seg.start >= occ.end {
                        newSegments.append(seg)
                    } else {
                        // Partial overlap — keep non-overlapping parts
                        if seg.start < occ.start {
                            newSegments.append((start: seg.start, end: occ.start))
                        }
                        if seg.end > occ.end {
                            newSegments.append((start: occ.end, end: seg.end))
                        }
                    }
                }
                remainingSegments = newSegments
            }

            // Add surviving segments
            for seg in remainingSegments {
                // Skip tiny segments (< 1 minute)
                guard seg.end.timeIntervalSince(seg.start) >= 60 else { continue }
                finalEntries.append((
                    start: seg.start,
                    end: seg.end,
                    category: entry.category,
                    source: entry.source,
                    confidence: entry.confidence,
                    metadata: entry.metadata
                ))
                occupied.append((start: seg.start, end: seg.end))
            }
        }

        return finalEntries.sorted { $0.start < $1.start }
    }

    // MARK: - Sleep Merging

    /// Merge contiguous sleep samples into single blocks.
    /// Samples within 30 minutes of each other are considered part of the same sleep session.
    private func mergeSleepSamples(_ samples: [SleepSample]) -> [(start: Date, end: Date)] {
        guard var current = samples.first.map({ (start: $0.startDate, end: $0.endDate) }) else { return [] }

        var merged: [(start: Date, end: Date)] = []
        let gap: TimeInterval = 30 * 60 // 30 minutes

        for sample in samples.dropFirst() {
            if sample.startDate.timeIntervalSince(current.end) <= gap {
                // Extend the current block
                current.end = max(current.end, sample.endDate)
            } else {
                // Gap too large — start a new block
                merged.append(current)
                current = (start: sample.startDate, end: sample.endDate)
            }
        }
        merged.append(current)

        return merged
    }

    // MARK: - Fajr Detection

    /// If the user is awake for 35+ minutes straight during a sleep session, classify it as Fajr prayer.
    private func detectFajrPrayer(
        awakePeriods: [SleepSample],
        sleepBlocks: [(start: Date, end: Date)]
    ) -> [(start: Date, end: Date)] {
        let fajrThreshold: TimeInterval = 35 * 60 // 35 minutes

        // Merge contiguous awake samples the same way we merge sleep
        let mergedAwake = mergeSleepSamples(awakePeriods)

        return mergedAwake.compactMap { awake -> (start: Date, end: Date)? in
            let duration = awake.end.timeIntervalSince(awake.start)
            guard duration >= fajrThreshold else { return nil }

            // Check that this awake period falls within or between sleep blocks
            let isWithinSleep = sleepBlocks.contains { sleep in
                // Awake period overlaps or is adjacent to a sleep block (within 10 min)
                awake.start >= sleep.start.addingTimeInterval(-600) &&
                awake.start <= sleep.end.addingTimeInterval(600)
            }
            guard isWithinSleep else { return nil }

            return (start: awake.start, end: awake.end)
        }
    }

    // MARK: - Category Mapping

    private func workoutCategoryName(for workout: WorkoutSample) -> String {
        switch workout.activityType {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        default: return "Exercise"
        }
    }

    private func motionCategoryName(for segment: ActivitySegment, context: ModelContext) -> String {
        switch segment.activity {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .automotive:
            // Check if this looks like a commute (moving between known places)
            return "Commute"
        case .stationary:
            // Try to determine what "stationary" means based on location
            if let place = location.detectCurrentPlace(context: context) {
                switch place.name.lowercased() {
                case let n where n.contains("work") || n.contains("office"): return "Work"
                case let n where n.contains("gym"): return "Exercise"
                case let n where n.contains("home"): return "Stationary"
                default: return "Stationary"
                }
            }
            return "Stationary"
        case .unknown:
            return "Other"
        }
    }

    // MARK: - Daily Snapshot

    private func updateSnapshot(for date: Date, context: ModelContext) async throws {
        let startOfDay = Calendar.current.startOfDay(for: date)

        let snapshotDescriptor = FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate<HealthSnapshot> { snapshot in
                snapshot.date == startOfDay
            }
        )
        let existing = (try? context.fetch(snapshotDescriptor)) ?? []
        for snapshot in existing {
            context.delete(snapshot)
        }

        let steps = (try? await healthKit.fetchSteps(for: date)) ?? 0
        let calories = (try? await healthKit.fetchActiveCalories(for: date)) ?? 0
        let sleepMinutes = (try? await healthKit.fetchTotalSleepMinutes(for: date)) ?? 0
        let workouts = (try? await healthKit.fetchWorkouts(for: date)) ?? []
        let workoutMinutes = workouts.reduce(0) { $0 + $1.durationMinutes }

        let snapshot = HealthSnapshot(
            date: date,
            steps: steps,
            activeCalories: calories,
            sleepMinutes: sleepMinutes,
            workoutMinutes: workoutMinutes,
            workoutCount: workouts.count
        )
        context.insert(snapshot)
    }
}
