import SwiftUI

struct DeskTimeDetailView: View {
    @State private var vm = DeskTimeViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if vm.isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else if vm.blocks.isEmpty {
                        EmptyStateView(
                            icon: "desktopcomputer",
                            title: "No desktop data",
                            subtitle: "Make sure ActivityWatch is running on your desktop"
                        )
                    } else {
                        DeskTimeHeroCard(
                            score: vm.scopedProductivityScore,
                            scoreLabel: vm.scoreLabel,
                            scoreSummary: vm.scoreSummary,
                            scoreColor: DeskTimeViewModel.colorForScore(vm.scopedProductivityScore)
                        )
                        .padding(.horizontal, 16)

                        HStack(spacing: 0) {
                            StatBadge(value: DeskTimeViewModel.formatMinutes(vm.scopedTotalMinutes), label: "total")
                            StatBadge(value: DeskTimeViewModel.formatMinutes(vm.scopedAvgPerDay), label: "avg/day")
                            StatBadge(value: DeskTimeViewModel.formatMinutes(vm.scopedLongestSession), label: "longest")
                        }
                        .card()
                        .padding(.horizontal, 16)

                        DeskTimeViewModePicker(viewMode: $vm.viewMode)
                            .padding(.horizontal, 16)

                        if vm.hasIPhoneData {
                            DeskTimeDeviceFilterPills(
                                selectedDevice: $vm.selectedDevice,
                                totalMinutes: vm.scopedTotalMinutes,
                                macMinutes: vm.scopedMacMinutes,
                                iphoneMinutes: vm.scopedIPhoneMinutes
                            )
                            .padding(.horizontal, 16)
                        }

                        if vm.viewMode == .daily {
                            DeskTimeTimelineBar(
                                blocks: vm.filteredBlocks,
                                hasIPhoneData: vm.hasIPhoneData
                            )
                            .padding(.horizontal, 16)
                        }

                        if !vm.scopedTierBreakdown.isEmpty {
                            DeskTimeTierBreakdown(
                                breakdown: vm.scopedTierBreakdown,
                                total: vm.scopedTotalMinutes
                            )
                            .padding(.horizontal, 16)
                        }

                        if !vm.scopedSiteStats.isEmpty {
                            DeskTimeWebsiteBreakdown(siteStats: vm.scopedSiteStats)
                                .padding(.horizontal, 16)
                        }

                        if !vm.scopedAppStats.isEmpty {
                            DeskTimeAppBreakdown(
                                appStats: vm.scopedAppStats,
                                hasIPhoneData: vm.hasIPhoneData
                            )
                            .padding(.horizontal, 16)
                        }

                        if vm.viewMode == .weekly && !vm.weeklyData.isEmpty {
                            DeskTimeWeeklyTrend(weeklyData: vm.weeklyData)
                                .padding(.horizontal, 16)
                        }

                        DeskTimeSessionList(
                            blocks: vm.scopedBlocks,
                            aiRefinedCount: vm.aiRefinedCount,
                            viewMode: vm.viewMode,
                            hasIPhoneData: vm.hasIPhoneData
                        )
                        .padding(.horizontal, 16)

                        DeskTimeHeatmapView()
                            .card()
                            .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Desk Time")
        .task { await vm.loadData() }
    }
}

// MARK: - StatBadge

private struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3).weight(.semibold).monospacedDigit())
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}
