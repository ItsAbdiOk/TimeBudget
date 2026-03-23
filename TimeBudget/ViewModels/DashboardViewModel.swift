import Foundation
import SwiftData
import SwiftUI

@Observable
final class DashboardViewModel {
    var steps: Int = 0
    var activeCalories: Double = 0
    var sleepMinutes: Int = 0
    var sleepSamples: [SleepSample] = []
    var workouts: [WorkoutSample] = []
    var todayEntries: [TimeEntry] = []
    var meetingMinutes: Int = 0
    var currentActivity: DetectedActivity = .unknown
    var currentPlaceName: String?
    var dailyScore: DailyScore?
    var isLoading = true
    var errorMessage: String?

    private let healthKit = HealthKitService.shared
    private let classifier = TimeClassifier.shared
    private let motion = MotionService.shared
    private let location = LocationService.shared
    private let calendarService = CalendarService.shared

    var sleepFormatted: String {
        let hours = sleepMinutes / 60
        let mins = sleepMinutes % 60
        return "\(hours)h \(mins)m"
    }

    var totalWorkoutMinutes: Int {
        workouts.reduce(0) { $0 + $1.durationMinutes }
    }

    var workoutFormatted: String {
        let hours = totalWorkoutMinutes / 60
        let mins = totalWorkoutMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    var meetingFormatted: String {
        let hours = meetingMinutes / 60
        let mins = meetingMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    var currentActivityText: String {
        var parts: [String] = []

        switch currentActivity {
        case .walking: parts.append("Walking")
        case .running: parts.append("Running")
        case .cycling: parts.append("Cycling")
        case .automotive: parts.append("Driving")
        case .stationary: parts.append("Stationary")
        case .unknown: parts.append("Unknown")
        }

        if let place = currentPlaceName {
            parts.append("at \(place)")
        }

        return parts.joined(separator: " ")
    }

    private var lastLoadDate: Date?

    func loadTodayData(context: ModelContext) async {
        // Throttle: don't reload if we loaded less than 30 seconds ago
        if let last = lastLoadDate, Date().timeIntervalSince(last) < 30, !isLoading {
            return
        }

        isLoading = true
        errorMessage = nil
        lastLoadDate = Date()

        let today = Date()

        // Fetch all health data in parallel — one round-trip instead of sequential
        async let stepsTask = try? healthKit.fetchSteps(for: today)
        async let caloriesTask = try? healthKit.fetchActiveCalories(for: today)
        async let sleepTask = try? healthKit.fetchSleepSamples(for: today)
        async let workoutsTask = try? healthKit.fetchWorkouts(for: today)
        async let motionTask: () = motion.fetchCurrentActivity()

        // AniList sync (throttled to once per hour, runs in parallel with HealthKit)
        let aniList = AniListService.shared
        async let aniListTask: () = {
            if aniList.shouldSync {
                await aniList.syncReadingActivity(for: today)
            }
        }()

        // Pocket Casts sync (parallel, throttled)
        let pocketCasts = PocketCastsService.shared
        async let pocketCastsTask: () = {
            if pocketCasts.isConfigured && pocketCasts.shouldSync {
                _ = try? await pocketCasts.fetchTodayEpisodes()
            }
        }()

        // ActivityWatch sync (parallel, graceful failure if unreachable)
        let activityWatch = ActivityWatchService.shared
        async let activityWatchTask: () = {
            if activityWatch.isConfigured && activityWatch.shouldSync {
                _ = try? await activityWatch.fetchTodayBlocks()
            }
        }()

        // Await all in parallel
        steps = await stepsTask ?? 0
        activeCalories = await caloriesTask ?? 0
        sleepSamples = await sleepTask ?? []
        sleepMinutes = sleepSamples.filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.durationMinutes }
        workouts = await workoutsTask ?? []
        await motionTask
        await aniListTask
        await pocketCastsTask
        await activityWatchTask

        currentActivity = motion.currentActivity

        // Calendar meetings (synchronous, fast)
        meetingMinutes = calendarService.totalMeetingMinutes(for: today)

        // Current place (synchronous, uses cached location)
        if let place = location.detectCurrentPlace(context: context) {
            currentPlaceName = place.name
        } else {
            currentPlaceName = nil
        }

        // Classify the day into TimeEntries
        do {
            try await classifier.classifyDay(date: today, context: context)
        } catch {
            errorMessage = "Failed to classify today's data"
        }

        // Fetch today's entries
        let startOfDay = Calendar.current.startOfDay(for: today)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startDate >= startOfDay && entry.startDate < endOfDay
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        todayEntries = (try? context.fetch(descriptor)) ?? []

        // Compute daily score
        let idealDescriptor = FetchDescriptor<IdealDay>()
        let idealTargets = (try? context.fetch(idealDescriptor)) ?? []
        if !idealTargets.isEmpty {
            let (overall, perCategory, totalMinutes) = DailyScore.compute(
                entries: todayEntries,
                idealTargets: idealTargets
            )
            dailyScore = DailyScore(
                date: today,
                overallScore: overall,
                categoryScores: perCategory,
                totalTrackedMinutes: totalMinutes
            )
        } else {
            dailyScore = nil
        }

        isLoading = false
    }
}
