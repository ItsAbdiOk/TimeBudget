import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Authorization

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Budget Exceeded

    func scheduleBudgetExceeded(categoryName: String, budgetMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Budget Exceeded"
        content.body = "You've gone over your \(categoryName) budget of \(formatMinutes(budgetMinutes)) today."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "budget_exceeded_\(categoryName)",
            content: content,
            trigger: nil // Fire immediately
        )
        center.add(request)
    }

    // MARK: - Stationary Nudge

    func scheduleStationaryNudge(afterMinutes: Int = 180) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Move"
        content.body = "You've been stationary for \(afterMinutes / 60) hours. A short walk can help!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(afterMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "stationary_nudge",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelStationaryNudge() {
        center.removePendingNotificationRequests(withIdentifiers: ["stationary_nudge"])
    }

    // MARK: - Weekly Report

    func scheduleWeeklyReport(summary: WeeklySummary) {
        let content = UNMutableNotificationContent()
        content.title = "Your Week in Review"
        content.body = "Sleep avg: \(formatMinutes(summary.avgSleepMinutes)) · Steps avg: \(summary.avgSteps) · Workouts: \(summary.totalWorkouts)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "weekly_report",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    // MARK: - Check Budgets

    func checkBudgets(budgets: [TimeBudgetModel], actualMinutes: [String: Int]) {
        for budget in budgets where budget.isActive {
            let actual = actualMinutes[budget.categoryName] ?? 0
            if actual > budget.effectiveMinutes {
                scheduleBudgetExceeded(
                    categoryName: budget.categoryName,
                    budgetMinutes: budget.effectiveMinutes
                )
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct WeeklySummary {
    let avgSleepMinutes: Int
    let avgSteps: Int
    let totalWorkouts: Int
    let avgScore: Double
}
