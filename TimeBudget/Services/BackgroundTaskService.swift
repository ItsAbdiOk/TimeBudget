import Foundation
import BackgroundTasks
import SwiftData

/// Manages BGAppRefreshTask for overnight syncing of AniList data
/// and batch processing of motion/health data.
///
/// iOS decides when to run these — typically overnight while charging.
/// We register the task identifiers at app launch and schedule them.
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

        let workTask = Task {
            // 1. Sync AniList reading data (last 7 days)
            await AniListService.shared.syncRecentActivity(days: 7)

            // 2. Pre-fetch current activity snapshot so dashboard loads faster
            await MotionService.shared.fetchCurrentActivity()
        }

        // If iOS needs to terminate us, cancel gracefully
        task.expirationHandler = {
            workTask.cancel()
        }

        // When done, mark complete
        Task {
            await workTask.value
            task.setTaskCompleted(success: true)
        }
    }
}
