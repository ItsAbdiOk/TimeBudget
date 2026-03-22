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
        // Location: significant changes + visits + geofencing (all hardware-managed, near-zero battery)
        let locationService = LocationService.shared
        if locationService.isAuthorized {
            locationService.startMonitoring()
            locationService.startMonitoringAllPlaces(context: modelContext)
        }

        // Motion: NO always-on updates. We use historical batch queries in TimeClassifier.
        // Live updates only start when a Focus Session is running (see FocusViewModel).
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
        case .dashboard: return "chart.pie"
        case .focus: return "timer"
        case .budget: return "calendar.badge.clock"
        case .insights: return "lightbulb"
        case .settings: return "gearshape"
        }
    }

    var iconFilled: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .focus: return "timer"
        case .budget: return "calendar.badge.clock"
        case .insights: return "lightbulb.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .dashboard: DashboardView()
                case .focus: FocusStopwatchView()
                case .budget: BudgetListView()
                case .insights: InsightsTabView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom frosted tab bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @Namespace private var tabAnimation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: tabAnimation
                ) {
                    Haptics.heavy()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.3)
        }
    }
}

struct TabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 48, height: 28)
                            .matchedGeometryEffect(id: "tabHighlight", in: namespace)
                    }

                    Image(systemName: isSelected ? tab.iconFilled : tab.icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }
                .frame(height: 28)

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
