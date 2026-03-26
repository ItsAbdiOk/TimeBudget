import Foundation
import SwiftData

// MARK: - Helper Methods

extension TimeClassifier {

    // MARK: - Sleep Merging

    /// Merge contiguous sleep samples into single blocks.
    /// Samples within 30 minutes of each other are considered part of the same sleep session.
    func mergeSleepSamples(_ samples: [SleepSample]) -> [(start: Date, end: Date)] {
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
    func detectFajrPrayer(
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

    // MARK: - Daily Snapshot

    func updateSnapshot(for date: Date, context: ModelContext) async throws {
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

    // MARK: - Category Mapping

    func workoutCategoryName(for workout: WorkoutSample) -> String {
        switch workout.activityType {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        default: return "Exercise"
        }
    }

    func motionCategoryName(for segment: ActivitySegment, context: ModelContext) -> String {
        switch segment.activity {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .automotive:
            // Check if this looks like a commute (moving between known places)
            return "Commute"
        case .stationary:
            // Try to determine what "stationary" means based on location
            if let place = location.currentPlace(context: context) {
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
}
