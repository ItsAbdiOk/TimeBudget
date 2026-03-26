import Foundation
import SwiftData

// MARK: - Data Source Collection

extension TimeClassifier {

    /// Collects time entries from all data sources for a given day.
    func collectEntries(
        date: Date,
        startOfDay: Date,
        endOfDay: Date,
        categoryMap: [String: ActivityCategory],
        context: ModelContext
    ) async -> [ClassifiedEntry] {
        var entries: [ClassifiedEntry] = []

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
            var blocks = (try? await activityWatch.fetchBlocks(for: date)) ?? []

            // 6b. Refine ALL blocks with Apple Intelligence
            if #available(iOS 26, *) {
                let enabled = UserDefaults.standard.bool(forKey: "intelligence_categorization_enabled")
                print("[Intelligence] Categorization enabled: \(enabled), blocks: \(blocks.count)")
                if enabled && !blocks.isEmpty {
                    let refinedCategories = await refineWithIntelligence(
                        blocks: blocks,
                        validCategories: Array(categoryMap.keys)
                    )
                    // Apply AI categories to blocks
                    var applied = 0
                    for i in blocks.indices {
                        if let aiCat = refinedCategories[blocks[i].id.uuidString] {
                            blocks[i].aiCategory = aiCat
                            applied += 1
                        }
                    }
                    print("[Intelligence] Applied AI categories to \(applied)/\(blocks.count) blocks")
                }
            }

            for block in blocks {
                let category = block.effectiveCategory
                var metadata = [
                    "topApp": block.topApp,
                    "source": "ActivityWatch",
                    "device": block.dominantDevice.rawValue
                ]
                if block.isAIRefined {
                    metadata["aiRefined"] = "true"
                    metadata["originalCategory"] = block.category
                }
                if let site = block.topSite {
                    metadata["topSite"] = site
                }
                entries.append((
                    start: block.start,
                    end: block.end,
                    category: category,
                    source: .activityWatch,
                    confidence: block.isAIRefined ? 0.85 : 0.8,
                    metadata: metadata
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

        return entries
    }
}
