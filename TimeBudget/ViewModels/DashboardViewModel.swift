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

    func loadTodayData(context: ModelContext) async {
        isLoading = true
        errorMessage = nil

        let today = Date()

        // Fetch health data
        do {
            steps = try await healthKit.fetchSteps(for: today)
        } catch {
            steps = 0
        }

        do {
            activeCalories = try await healthKit.fetchActiveCalories(for: today)
        } catch {
            activeCalories = 0
        }

        do {
            sleepMinutes = try await healthKit.fetchTotalSleepMinutes(for: today)
            sleepSamples = try await healthKit.fetchSleepSamples(for: today)
        } catch {
            sleepMinutes = 0
            sleepSamples = []
        }

        do {
            workouts = try await healthKit.fetchWorkouts(for: today)
        } catch {
            workouts = []
        }

        // Calendar meetings
        meetingMinutes = calendarService.totalMeetingMinutes(for: today)

        // Current activity: one-shot query (no persistent sensor subscription)
        await motion.fetchCurrentActivity()
        currentActivity = motion.currentActivity

        // Current place
        if let place = location.detectCurrentPlace(context: context) {
            currentPlaceName = place.name
        } else {
            currentPlaceName = nil
        }

        // Sync AniList reading data (throttled to once per hour)
        let aniList = AniListService.shared
        if aniList.shouldSync {
            await aniList.syncReadingActivity(for: today)
        }

        // Classify the day into TimeEntries (uses cached AniList data, batch motion query)
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
