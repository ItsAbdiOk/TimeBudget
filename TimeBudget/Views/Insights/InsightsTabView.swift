import SwiftUI
import SwiftData

struct InsightsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = InsightsViewModel()
    @AppStorage("anilist_username") private var aniListUsername = ""
    @AppStorage("leetcode_username") private var leetCodeUsername = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Focus / Fragmentation card
                        FragmentationCard(
                            score: viewModel.fragmentationScore,
                            label: viewModel.fragmentationLabel
                        )
                        .slideUpAppear(index: 0)
                        .padding(.horizontal, 16)

                        // Correlations
                        if !viewModel.correlations.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "Correlations", subtitle: "Patterns from your last 90 days")
                                    .padding(.horizontal, 16)

                                ForEach(Array(viewModel.correlations.enumerated()), id: \.element.factorA) { index, correlation in
                                    CorrelationCard(correlation: correlation)
                                        .slideUpAppear(index: index + 1)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Week Comparison
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Week vs Week")
                                .padding(.horizontal, 16)

                            WeekComparisonView()
                                .card()
                                .padding(.horizontal, 16)
                        }
                        .slideUpAppear(index: 3)

                        // 30-Day Trends
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "30-Day Trends")
                                .padding(.horizontal, 16)

                            TrendsView()
                                .card()
                                .padding(.horizontal, 16)
                        }
                        .slideUpAppear(index: 4)

                        // Activity Heatmap
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Activity", subtitle: "Your daily activity")
                                .padding(.horizontal, 16)

                            HeatmapView()
                                .card()
                                .padding(.horizontal, 16)
                        }
                        .slideUpAppear(index: 5)

                        // AniList Reading Heatmap (only if configured)
                        if !aniListUsername.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "Manga", subtitle: "Your reading activity")
                                    .padding(.horizontal, 16)

                                AniListHeatmapView()
                                    .card()
                                    .padding(.horizontal, 16)
                            }
                            .slideUpAppear(index: 6)
                        }

                        // LeetCode Heatmap (only if configured)
                        if !leetCodeUsername.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "LeetCode", subtitle: "Your coding practice")
                                    .padding(.horizontal, 16)

                                LeetCodeHeatmapView()
                                    .card()
                                    .padding(.horizontal, 16)
                            }
                            .slideUpAppear(index: 7)
                        }

                        Spacer().frame(height: 90)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Insights")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .task {
                await viewModel.loadInsights(context: modelContext)
            }
        }
    }
}

// MARK: - Fragmentation Card

struct FragmentationCard: View {
    let score: Double
    let label: String

    private var color: Color {
        switch score {
        case 0.8...: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            CircularProgress(
                progress: score,
                lineWidth: 8,
                color: color
            )
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S FOCUS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)

                Text(label)
                    .font(.system(.title2, design: .rounded).weight(.bold))

                Text("Fewer context switches = deeper work")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .card()
    }
}

// MARK: - Correlation Card

struct CorrelationCard: View {
    let correlation: Correlation

    private var strengthColor: Color {
        switch correlation.strengthLabel {
        case "Strong": return .green
        case "Moderate": return .blue
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill((correlation.coefficient > 0 ? Color.green : Color.orange).opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: correlation.coefficient > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(correlation.coefficient > 0 ? .green : .orange)
                }

                Text("\(correlation.factorA) → \(correlation.factorB)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))

                Spacer()

                ChipView(text: correlation.strengthLabel, color: strengthColor, isSelected: true)
            }

            Text(correlation.insight)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(correlation.sampleSize) days analyzed")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .card()
    }
}
