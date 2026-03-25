import SwiftUI
import SwiftData

@main
struct TimeBudgetApp: App {
    let modelContainer: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
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
            modelContainer = try ModelContainer(for: schema, configurations: [config])

            // Seed default categories on first launch
            let context = modelContainer.mainContext
            let descriptor = FetchDescriptor<ActivityCategory>()
            let existingCount = (try? context.fetchCount(descriptor)) ?? 0
            if existingCount == 0 {
                ActivityCategory.seedDefaults(into: context)
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Register background tasks for overnight AniList sync
        BackgroundTaskService.shared.registerTasks()

        // Register UserDefaults for Apple Intelligence (so bool(forKey:) returns true by default)
        UserDefaults.standard.register(defaults: [
            "intelligence_categorization_enabled": true,
            "intelligence_conflicts_enabled": true
        ])

        // Warm up Apple Intelligence model in background
        if #available(iOS 26, *) {
            Task.detached(priority: .background) {
                await IntelligenceService.shared.warmUp()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        BackgroundTaskService.shared.scheduleAppRefresh()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
