import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    LoadingStateView()
                } else if viewModel.todayEntries.isEmpty && viewModel.workouts.isEmpty {
                    EmptyStateView(
                        icon: "clock.badge.questionmark",
                        title: "No data yet today",
                        subtitle: "Wear your Apple Watch and check back later — your day will fill in automatically"
                    )
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 20) {
                        // Current activity pill
                        ActivityBanner(
                            activityText: viewModel.currentActivityText,
                            icon: activityIcon,
                            color: activityColor
                        )
                        .slideUpAppear(index: 0)
                        .padding(.horizontal, 16)

                        // Summary stat cards
                        StatsGrid(viewModel: viewModel)
                            .slideUpAppear(index: 1)
                            .padding(.horizontal, 16)

                        // Daily score card
                        if let score = viewModel.dailyScore {
                            DailyScoreCard(score: score)
                                .slideUpAppear(index: 2)
                                .padding(.horizontal, 16)
                        }

                        // Timeline ring
                        if !viewModel.todayEntries.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Your Day")
                                    .padding(.horizontal, 16)

                                TimelineRingWithLabels(entries: viewModel.todayEntries, date: Date())
                                    .padding(.horizontal, 16)
                            }
                            .slideUpAppear(index: 3)
                        }

                        // Pie chart
                        if !viewModel.todayEntries.isEmpty {
                            TimePieChartView(entries: viewModel.todayEntries)
                                .slideUpAppear(index: 4)
                        }

                        // Workouts
                        if !viewModel.workouts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Workouts")
                                    .padding(.horizontal, 16)

                                ForEach(viewModel.workouts, id: \.startDate) { workout in
                                    WorkoutRow(workout: workout)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .slideUpAppear(index: 5)
                        }

                        // Timeline entries
                        if !viewModel.todayEntries.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Timeline")
                                    .padding(.horizontal, 16)

                                ForEach(viewModel.todayEntries, id: \.id) { entry in
                                    TimeEntryRow(entry: entry)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .slideUpAppear(index: 6)
                        }

                        // Bottom spacer for tab bar
                        Spacer().frame(height: 90)
                    }
                    .padding(.top, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .refreshable {
                Haptics.medium()
                await viewModel.loadTodayData(context: modelContext)
            }
        }
        .task {
            await viewModel.loadTodayData(context: modelContext)
        }
    }

    private var activityIcon: String {
        switch viewModel.currentActivity {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .automotive: return "car.fill"
        case .stationary: return "figure.stand"
        case .unknown: return "questionmark"
        }
    }

    private var activityColor: Color {
        switch viewModel.currentActivity {
        case .walking: return .cyan
        case .running: return .orange
        case .cycling: return .yellow
        case .automotive: return .pink
        case .stationary: return .gray
        case .unknown: return .gray
        }
    }
}

// MARK: - Loading State

private struct LoadingStateView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.blue.opacity(0.6))
                        .rotationEffect(.degrees(pulse ? 360 : 0))
                }
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        pulse = true
                    }
                }

            Text("Loading your day...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - Activity Banner

struct ActivityBanner: View {
    let activityText: String
    let icon: String
    let color: Color
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("RIGHT NOW")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)

                Text(activityText)
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }

            Spacer()

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .scaleEffect(appeared ? 1.0 : 0.5)
                .opacity(appeared ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: appeared)
        }
        .card()
        .onAppear { appeared = true }
    }
}

// MARK: - Stats Grid

struct StatsGrid: View {
    let viewModel: DashboardViewModel

    private var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: viewModel.steps)) ?? "\(viewModel.steps)"
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatCard(title: "Steps", value: formattedSteps, icon: "figure.walk", color: .cyan)
            StatCard(title: "Calories", value: "\(Int(viewModel.activeCalories))", icon: "flame.fill", color: .orange)
            StatCard(title: "Sleep", value: viewModel.sleepFormatted, icon: "moon.zzz.fill", color: .indigo)
            StatCard(title: "Workouts", value: viewModel.workoutFormatted, icon: "figure.run", color: .green)
            StatCard(title: "Meetings", value: viewModel.meetingFormatted, icon: "person.2.fill", color: .purple)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Daily Score Card

struct DailyScoreCard: View {
    let score: DailyScore

    private var gradeColor: Color {
        switch score.overallScore {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            CircularProgress(
                progress: score.overallScore / 100.0,
                lineWidth: 8,
                color: gradeColor
            )
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("DAILY SCORE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(score.scoreFormatted)
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("/ 100")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text(score.scoreGrade)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(gradeColor)
            }

            Spacer()
        }
        .card()
    }
}

// MARK: - Workout Row

struct WorkoutRow: View {
    let workout: WorkoutSample

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: "figure.run")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(workout.durationMinutes)m · \(Int(workout.totalCalories)) cal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(workout.startDate.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .card()
    }
}

// MARK: - Time Entry Row

struct TimeEntryRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(entry.category?.color ?? .gray)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category?.name ?? "Unknown")
                    .font(.subheadline.weight(.semibold))
                Text(entry.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.endDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .card(padding: 12)
    }
}
