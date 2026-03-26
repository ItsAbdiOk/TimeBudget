import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    DashboardLoadingView()
                } else if viewModel.todayEntries.isEmpty && viewModel.workouts.isEmpty {
                    EmptyStateView(
                        icon: "clock.badge.questionmark",
                        title: "No data yet today",
                        subtitle: "Wear your Apple Watch and check back later — your day will fill in automatically"
                    )
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 20) {
                        // Greeting hero (no card)
                        GreetingHero()
                            .slideUpAppear(index: 0)
                            .padding(.horizontal, 16)

                        // Score card
                        if let score = viewModel.dailyScore {
                            ScoreHeroCard(
                                score: score,
                                entries: viewModel.todayEntries
                            )
                            .slideUpAppear(index: 1)
                            .padding(.horizontal, 16)
                        }

                        // Mini stats row
                        DashboardStatsGrid(
                            steps: viewModel.steps,
                            sleepMinutes: viewModel.sleepMinutes,
                            workouts: viewModel.workouts
                        )
                        .slideUpAppear(index: 2)
                        .padding(.horizontal, 16)

                        // 24-Hour Ring
                        if !viewModel.todayEntries.isEmpty {
                            DayRingCard(entries: viewModel.todayEntries)
                                .slideUpAppear(index: 3)
                                .padding(.horizontal, 16)
                        }

                        // Timeline section
                        if !viewModel.todayEntries.isEmpty {
                            TimelineSection(entries: viewModel.todayEntries)
                                .slideUpAppear(index: 4)
                                .padding(.horizontal, 16)
                        }

                        // Insight card
                        DashboardInsightCard(entries: viewModel.todayEntries)
                            .slideUpAppear(index: 5)
                            .padding(.horizontal, 16)

                        // Sources row
                        SourcesRow(entries: viewModel.todayEntries)
                            .slideUpAppear(index: 6)
                            .padding(.horizontal, 16)

                        Spacer().frame(height: 90)
                    }
                    .padding(.top, 8)
                }
            }
            .background(Color(.systemBackground))
            .refreshable {
                Haptics.medium()
                await viewModel.loadTodayData(context: modelContext)
            }
        }
        .task {
            await viewModel.loadTodayData(context: modelContext)
        }
    }
}
