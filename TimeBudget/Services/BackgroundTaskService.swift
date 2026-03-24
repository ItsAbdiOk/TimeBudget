import Foundation
import BackgroundTasks
import SwiftData

/// Manages BGAppRefreshTask for overnight aggregation.
///
/// iOS decides when to run these — typically overnight while charging.
/// The handler queries all historical data sources for yesterday,
/// runs TimeClassifier to build TimeEntries, and syncs external services.
final class BackgroundTaskService {
    static let shared = BackgroundTaskService()

    static let refreshTaskID = "com.timebudget.app.refresh"

    // MARK: - Registration (call once at app launch)

    func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: refreshTask)
        }
    }

    // MARK: - Scheduling (call when app enters background)

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        // Ask iOS to run this no earlier than 1 hour from now
        // In practice iOS runs it overnight while charging
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Scheduling can fail in simulator or when rate-limited — that's fine
        }
    }

    // MARK: - Task Handling

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh before we start work
        scheduleAppRefresh()

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let workTask = Task {
            await aggregateDay(yesterday)
        }

        task.expirationHandler = {
            workTask.cancel()
        }

        Task {
            await workTask.value
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Day Aggregation (standalone context for background safety)

    /// Aggregate all data sources for a given day.
    /// Creates its own ModelContainer/ModelContext so it's safe to call
    /// from a background task without touching the main context.
    func aggregateDay(_ date: Date) async {
        do {
            let schema = Schema([
                TimeEntry.self,
                ActivityCategory.self,
                HealthSnapshot.self,
                LocationPlace.self,
                FocusSession.self,
                IdealDay.self,
                DailyScore.self,
                TimeBudgetModel.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.autosaveEnabled = false

            // Sync external services
            await AniListService.shared.syncRecentActivity(days: 7)

            let pocketCasts = PocketCastsService.shared
            if pocketCasts.isConfigured {
                _ = try? await pocketCasts.fetchTodayEpisodes()
            }

            let activityWatch = ActivityWatchService.shared
            if activityWatch.isConfigured {
                _ = try? await activityWatch.fetchTodayBlocks()
            }

            // Classify the day
            try await TimeClassifier.shared.classifyDay(date: date, context: context)
            try context.save()
        } catch {
            print("[BackgroundTask] aggregateDay failed: \(error.localizedDescription)")
        }
    }
}
