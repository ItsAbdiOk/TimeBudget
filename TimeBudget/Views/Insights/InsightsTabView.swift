import SwiftUI
import SwiftData

struct InsightsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = InsightsViewModel()
    @AppStorage("anilist_username") private var aniListUsername = ""
    @AppStorage("leetcode_username") private var leetCodeUsername = ""
    @AppStorage("activitywatch_hostname") private var awHostname = ""
    @State private var hasPocketCastsToken = PocketCastsService.shared.isConfigured

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // Hero
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Insights")
                                .font(.system(size: 32, weight: .bold))
                                .tracking(-0.8)
                            Text("30-day patterns and trends.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 24)
                        .padding(.bottom, 4)
                        .slideUpAppear(index: 0)

                        // Trend Grid (2x2)
                        if !viewModel.trendMetrics.isEmpty {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)
                                ],
                                spacing: 10
                            ) {
                                ForEach(Array(viewModel.trendMetrics.enumerated()), id: \.element.id) { index, metric in
                                    TrendCardView(metric: metric)
                                        .slideUpAppear(index: index + 1)
                                }
                            }
                        }

                        // Activity Heatmap
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink {
                                ActivityDetailView()
                            } label: {
                                HStack {
                                    Text("Activity Heatmap")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color(.label))
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text("Last 15 weeks")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color(.secondaryLabel))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color(.tertiaryLabel))
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            HeatmapView()
                        }
                        .card()
                        .slideUpAppear(index: 5)

                        // Correlations (single grouped card)
                        if !viewModel.correlations.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Correlations")
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(.bottom, 10)

                                ForEach(Array(viewModel.correlations.enumerated()), id: \.element.factorA) { index, correlation in
                                    if index > 0 {
                                        Divider()
                                    }
                                    CorrelationRow(correlation: correlation)
                                }
                            }
                            .card()
                            .slideUpAppear(index: 6)
                        }

                        // AniList Reading Heatmap (only if configured)
                        if !aniListUsername.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                NavigationLink {
                                    MangaDetailView()
                                } label: {
                                    TappableSectionHeader(title: "Manga", subtitle: "Your reading activity")
                                }
                                .buttonStyle(.plain)

                                AniListHeatmapView()
                                    .card()
                            }
                            .slideUpAppear(index: 7)
                        }

                        // LeetCode Heatmap (only if configured)
                        if !leetCodeUsername.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                NavigationLink {
                                    LeetCodeDetailView()
                                } label: {
                                    TappableSectionHeader(title: "LeetCode", subtitle: "Your coding practice")
                                }
                                .buttonStyle(.plain)

                                LeetCodeHeatmapView()
                                    .card()
                            }
                            .slideUpAppear(index: 8)
                        }

                        // Podcast Heatmap (only if configured)
                        if hasPocketCastsToken {
                            VStack(alignment: .leading, spacing: 10) {
                                NavigationLink {
                                    PodcastDetailView()
                                } label: {
                                    TappableSectionHeader(title: "Podcasts", subtitle: "Your listening activity")
                                }
                                .buttonStyle(.plain)

                                PodcastHeatmapView()
                                    .card()
                            }
                            .slideUpAppear(index: 9)
                        }

                        // Desk Time Heatmap (only if configured)
                        if !awHostname.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                NavigationLink {
                                    DeskTimeDetailView()
                                } label: {
                                    TappableSectionHeader(title: "Desk Time", subtitle: "Your desktop activity")
                                }
                                .buttonStyle(.plain)

                                DeskTimeHeatmapView()
                                    .card()
                            }
                            .slideUpAppear(index: 10)
                        }

                        Spacer().frame(height: 90)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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

// MARK: - Correlation Row

private struct CorrelationRow: View {
    let correlation: Correlation

    private var iconColor: Color {
        correlation.coefficient > 0 ? Color(.systemGreen) : Color(.systemOrange)
    }

    private var strengthColor: Color {
        switch correlation.strengthLabel {
        case "Strong": return Color(.systemGreen)
        case "Moderate": return Color(.systemPurple)
        default: return Color(.systemOrange)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon box
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconColor)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: correlation.coefficient > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }

            // Description
            Text(correlation.insight)
                .font(.system(size: 13))
                .foregroundStyle(Color(.label))
                .lineLimit(2)

            Spacer(minLength: 4)

            // Strength badge
            Text(correlation.strengthLabel)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(strengthColor.opacity(0.12))
                .foregroundStyle(strengthColor)
                .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
        }
        .padding(.vertical, 9)
    }
}

// MARK: - Trend Card View

private struct TrendCardView: View {
    let metric: TrendMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Color(.tertiaryLabel))

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(metric.value)
                    .font(.system(size: 26, weight: .semibold))
                    .monospacedDigit()
                Text(metric.unit)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text(metric.deltaText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(metric.deltaPositive ? Color(.systemGreen) : Color(.systemRed))

            SparklineView(points: metric.sparklinePoints, color: metric.accentColor)
                .frame(height: 30)
                .padding(.top, 4)
        }
        .card(padding: 16)
    }
}

// MARK: - Sparkline View

private struct SparklineView: View {
    let points: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard points.count >= 2 else { return }

                let stepX = geo.size.width / CGFloat(points.count - 1)
                let height = geo.size.height

                for (index, point) in points.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height * (1.0 - point)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Tappable Section Header

struct TappableSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(.label))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
    }
}
