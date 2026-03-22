import Foundation
import HealthKit

@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()
    private(set) var isAuthorized = false

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType(),
        ]

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    // MARK: - Steps

    func fetchSteps(for date: Date) async throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let statistics = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatistics?, Error>) in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: statistics)
                }
            }
            healthStore.execute(query)
        }

        return Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
    }

    // MARK: - Active Calories

    func fetchActiveCalories(for date: Date) async throws -> Double {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let statistics = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatistics?, Error>) in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: statistics)
                }
            }
            healthStore.execute(query)
        }

        return statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }

    // MARK: - Sleep

    func fetchSleepSamples(for date: Date) async throws -> [SleepSample] {
        let startOfPreviousEvening = Calendar.current.date(byAdding: .hour, value: -12, to: Calendar.current.startOfDay(for: date))!
        let endOfMorning = Calendar.current.date(byAdding: .hour, value: 12, to: Calendar.current.startOfDay(for: date))!

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfPreviousEvening, end: endOfMorning, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        return samples.compactMap { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            guard value != .inBed else { return nil }

            let stage: SleepStage
            switch value {
            case .asleepCore: stage = .core
            case .asleepDeep: stage = .deep
            case .asleepREM: stage = .rem
            case .asleepUnspecified: stage = .unspecified
            case .awake: stage = .awake
            default: stage = .unspecified
            }

            return SleepSample(
                startDate: sample.startDate,
                endDate: sample.endDate,
                stage: stage
            )
        }
    }

    func fetchTotalSleepMinutes(for date: Date) async throws -> Int {
        let samples = try await fetchSleepSamples(for: date)
        let totalSeconds = samples
            .filter { $0.stage != .awake }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return Int(totalSeconds / 60)
    }

    // MARK: - Workouts

    func fetchWorkouts(for date: Date) async throws -> [WorkoutSample] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
            }
            healthStore.execute(query)
        }

        return samples.map { workout in
            WorkoutSample(
                startDate: workout.startDate,
                endDate: workout.endDate,
                activityType: workout.workoutActivityType,
                totalCalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                durationMinutes: Int(workout.duration / 60)
            )
        }
    }

    // MARK: - Batch Range Queries

    func fetchWorkoutsInRange(from start: Date, to end: Date) async throws -> [WorkoutSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
            }
            healthStore.execute(query)
        }

        return samples.map { workout in
            WorkoutSample(
                startDate: workout.startDate,
                endDate: workout.endDate,
                activityType: workout.workoutActivityType,
                totalCalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                durationMinutes: Int(workout.duration / 60)
            )
        }
    }

    func fetchSleepSamplesInRange(from start: Date, to end: Date) async throws -> [SleepSample] {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        return samples.compactMap { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            guard value != .inBed else { return nil }

            let stage: SleepStage
            switch value {
            case .asleepCore: stage = .core
            case .asleepDeep: stage = .deep
            case .asleepREM: stage = .rem
            case .asleepUnspecified: stage = .unspecified
            case .awake: stage = .awake
            default: stage = .unspecified
            }

            return SleepSample(
                startDate: sample.startDate,
                endDate: sample.endDate,
                stage: stage
            )
        }
    }

    func fetchStepsInRange(from start: Date, to end: Date) async throws -> [(date: Date, steps: Int)] {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let interval = DateComponents(day: 1)
        let anchorDate = Calendar.current.startOfDay(for: start)

        let results = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKStatistics], Error>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: collection?.statistics() ?? [])
                }
            }
            healthStore.execute(query)
        }

        return results.map { stat in
            (date: stat.startDate, steps: Int(stat.sumQuantity()?.doubleValue(for: .count()) ?? 0))
        }
    }

    // MARK: - Historical Backfill

    func fetchDailySnapshots(days: Int) async throws -> [HealthSnapshot] {
        var snapshots: [HealthSnapshot] = []
        let today = Date()

        for dayOffset in 0..<days {
            guard let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

            let steps = (try? await fetchSteps(for: date)) ?? 0
            let calories = (try? await fetchActiveCalories(for: date)) ?? 0
            let sleepMinutes = (try? await fetchTotalSleepMinutes(for: date)) ?? 0
            let workouts = (try? await fetchWorkouts(for: date)) ?? []
            let workoutMinutes = workouts.reduce(0) { $0 + $1.durationMinutes }

            let snapshot = HealthSnapshot(
                date: date,
                steps: steps,
                activeCalories: calories,
                sleepMinutes: sleepMinutes,
                workoutMinutes: workoutMinutes,
                workoutCount: workouts.count
            )
            snapshots.append(snapshot)
        }

        return snapshots
    }
}

// MARK: - Supporting Types

struct SleepSample {
    let startDate: Date
    let endDate: Date
    let stage: SleepStage

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
}

enum SleepStage: String {
    case core, deep, rem, awake, unspecified
}

struct WorkoutSample {
    let startDate: Date
    let endDate: Date
    let activityType: HKWorkoutActivityType
    let totalCalories: Double
    let durationMinutes: Int

    var name: String {
        switch activityType {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .hiking: return "Hiking"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        default: return "Workout"
        }
    }
}
