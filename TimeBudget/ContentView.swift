import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
                .onAppear {
                    startPassiveTracking()
                }
        } else {
            OnboardingFlow()
        }
    }

    private func startPassiveTracking() {
        // Geofencing only — hardware-managed, zero battery cost
        let locationService = LocationService.shared
        if locationService.isAuthorized {
            locationService.startMonitoringAllPlaces(context: modelContext)
        }

        // No live motion/GPS. App is a historical aggregator:
        // HealthKit, Core Motion, and Calendar are queried on-demand via TimeClassifier.
    }
}

// MARK: - Tab Definition

enum AppTab: Int, CaseIterable {
    case dashboard, focus, budget, insights, settings

    var label: String {
        switch self {
        case .dashboard: return "Today"
        case .focus: return "Focus"
        case .budget: return "Budget"
        case .insights: return "Insights"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "circle.dotted"
        case .focus: return "timer"
        case .budget: return "chart.bar"
        case .insights: return "waveform.path.ecg"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(AppTab.dashboard.label, systemImage: AppTab.dashboard.icon)
                }
                .tag(AppTab.dashboard)

            FocusStopwatchView()
                .tabItem {
                    Label(AppTab.focus.label, systemImage: AppTab.focus.icon)
                }
                .tag(AppTab.focus)

            BudgetListView()
                .tabItem {
                    Label(AppTab.budget.label, systemImage: AppTab.budget.icon)
                }
                .tag(AppTab.budget)

            InsightsTabView()
                .tabItem {
                    Label(AppTab.insights.label, systemImage: AppTab.insights.icon)
                }
                .tag(AppTab.insights)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.label, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(Color(.systemBlue))
    }
}
