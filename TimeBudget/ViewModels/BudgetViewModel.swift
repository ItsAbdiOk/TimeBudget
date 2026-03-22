import Foundation
import SwiftData

@Observable
final class BudgetViewModel {
    var budgets: [TimeBudgetModel] = []
    var actualMinutes: [String: Int] = [:]
    var isLoading = false

    func loadBudgets(context: ModelContext) {
        let descriptor = FetchDescriptor<TimeBudgetModel>(
            sortBy: [SortDescriptor(\.categoryName)]
        )
        budgets = (try? context.fetch(descriptor)) ?? []
        loadActualMinutes(context: context)
    }

    func loadActualMinutes(context: ModelContext) {
        let today = Date()
        let startOfDay = Calendar.current.startOfDay(for: today)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { entry in
                entry.startDate >= startOfDay && entry.startDate < endOfDay
            }
        )
        let entries = (try? context.fetch(descriptor)) ?? []

        actualMinutes = [:]
        for entry in entries {
            let name = entry.category?.name ?? "Other"
            actualMinutes[name, default: 0] += entry.durationMinutes
        }

        // Check budgets for notifications
        NotificationService.shared.checkBudgets(budgets: budgets, actualMinutes: actualMinutes)
    }

    func deleteBudget(_ budget: TimeBudgetModel, context: ModelContext) {
        context.delete(budget)
        try? context.save()
        loadBudgets(context: context)
    }

    func saveBudget(
        categoryName: String,
        targetMinutes: Int,
        allowRollover: Bool,
        context: ModelContext
    ) {
        let budget = TimeBudgetModel(
            categoryName: categoryName,
            targetMinutesPerDay: targetMinutes,
            allowRollover: allowRollover
        )
        context.insert(budget)
        try? context.save()
        loadBudgets(context: context)
    }
}
