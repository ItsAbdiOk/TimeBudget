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
                        MiniStatsRow(viewModel: viewModel)
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
                        InsightCard(entries: viewModel.todayEntries)
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

// MARK: - Greeting Hero

private struct GreetingHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date line
            Text(dateString.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color(.tertiaryLabel))

            // Greeting with bold name
            (Text(greetingPrefix + ",\n")
                .font(.system(size: 34, weight: .bold))
             + Text("Abdi.")
                .font(.system(size: 34, weight: .heavy)))
                .tracking(-0.4)
                .lineSpacing(2)

            // Contextual subtitle
            Text(subtitleText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }

    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<5: return "Late night"
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    private var subtitleText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        // Contextual deep work hint based on time of day
        if hour < 9 {
            let minsUntilNine = (9 - hour) * 60 - minute
            return "Your deep work window opens in \(minsUntilNine) minutes."
        } else if hour < 12 {
            return "You're in your peak focus window right now."
        } else if hour < 17 {
            return "Afternoon — a great time for lighter tasks."
        } else {
            return "Wind down and review your day."
        }
    }
}

// MARK: - Score Hero Card

private struct ScoreHeroCard: View {
    let score: DailyScore
    let entries: [TimeEntry]

    private var gradeColor: Color {
        switch score.overallScore {
        case 80...100: return Color(.systemGreen)
        case 60..<80: return Color(.systemOrange)
        default: return Color(.systemRed)
        }
    }

    private var gradeTag: String {
        switch score.overallScore {
        case 90...100: return "CRUSHING IT"
        case 80..<90: return "ON TRACK"
        case 70..<80: return "SOLID"
        case 55..<70: return "STEADY"
        default: return "WARMING UP"
        }
    }

    private var headlineText: AttributedString {
        let label: String
        switch score.overallScore {
        case 85...100: label = "An **excellent day.**"
        case 70..<85: label = "A **solid day.**"
        case 55..<70: label = "A **steady day.**"
        default: label = "A **slow start.**"
        }
        return (try? AttributedString(markdown: label)) ?? AttributedString(label)
    }

    private var descriptionText: String {
        let tracked = score.totalTrackedMinutes
        let hours = tracked / 60
        let mins = tracked % 60
        if hours > 0 {
            return "You've tracked \(hours)h \(mins)m across \(categoryPills.count) categories so far today."
        }
        return "You've tracked \(mins)m across \(categoryPills.count) categories so far today."
    }

    private var categoryPills: [(name: String, color: Color)] {
        var seen = Set<String>()
        var result: [(name: String, color: Color)] = []
        for entry in entries {
            let name = entry.category?.name ?? "Other"
            if seen.insert(name).inserted {
                result.append((name: name, color: entry.category?.color ?? Color(.systemGray)))
            }
        }
        return result
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Ring with score
            VStack(spacing: 6) {
                CircularProgress(
                    progress: score.overallScore / 100.0,
                    lineWidth: 8,
                    color: gradeColor,
                    showLabel: false
                )
                .frame(width: 68, height: 68)
                .overlay {
                    Text(score.scoreFormatted)
                        .font(.system(size: 26, weight: .semibold))
                        .monospacedDigit()
                }

                Text(gradeTag)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(gradeColor)
            }

            // Right side: headline + description + pills
            VStack(alignment: .leading, spacing: 8) {
                Text(headlineText)
                    .font(.system(size: 20, weight: .semibold))

                Text(descriptionText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(3)

                // Category pills
                FlowLayout(spacing: 6) {
                    ForEach(categoryPills, id: \.name) { pill in
                        CategoryPill(name: pill.name, color: pill.color)
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .heroCard()
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.label))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Mini Stats Row

private struct MiniStatsRow: View {
    let viewModel: DashboardViewModel

    private var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: viewModel.steps)) ?? "\(viewModel.steps)"
    }

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        LazyVGrid(columns: columns, spacing: 10) {
            MiniStatCard(label: "STEPS", value: formattedSteps, unit: nil, delta: "\u{2191} 8%", deltaPositive: true)
            MiniStatCard(label: "SLEEP", value: sleepValue, unit: sleepUnit, delta: "\u{2193} 10m", deltaPositive: false)
            MiniStatCard(label: "EXERCISE", value: exerciseValue, unit: exerciseUnit, delta: "\u{2191} 12%", deltaPositive: true)
        }
    }

    private var sleepValue: String {
        let hours = viewModel.sleepMinutes / 60
        return "\(hours)"
    }

    private var sleepUnit: String {
        let mins = viewModel.sleepMinutes % 60
        return "h \(mins)m"
    }

    private var exerciseValue: String {
        let totalMinutes = viewModel.workouts.reduce(0) { $0 + $1.durationMinutes }
        return "\(totalMinutes)"
    }

    private var exerciseUnit: String {
        return "min"
    }
}

// MARK: - Mini Stat Card

private struct MiniStatCard: View {
    let label: String
    let value: String
    let unit: String?
    let delta: String
    let deltaPositive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color(.tertiaryLabel))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text(delta)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(deltaPositive ? Color(.systemGreen) : Color(.systemRed))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

// MARK: - 24-Hour Ring Card

private struct DayRingCard: View {
    let entries: [TimeEntry]

    private var totalTracked: String {
        let total = entries.reduce(0) { $0 + $1.durationMinutes }
        let h = total / 60
        let m = total % 60
        return "\(h)h \(m)m"
    }

    private var legendItems: [(name: String, color: Color)] {
        var seen = Set<String>()
        var result: [(name: String, color: Color)] = []
        for entry in entries {
            let name = entry.category?.name ?? "Other"
            if seen.insert(name).inserted {
                result.append((name: name, color: entry.category?.color ?? Color(.systemGray)))
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 16) {
            // Title row
            HStack {
                Text("24-Hour Ring")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("Today")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            // Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 20)

                // Hour tick marks (every 30 degrees = 12 ticks)
                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) * 30.0
                    Rectangle()
                        .fill(Color(.tertiaryLabel))
                        .frame(width: 1, height: 8)
                        .offset(y: -85)
                        .rotationEffect(.degrees(angle))
                }

                // Entry arcs
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    let startAngle = angleForTime(entry.startDate)
                    let endAngle = angleForTime(entry.endDate)
                    Circle()
                        .trim(from: normalizeAngle(startAngle), to: normalizeAngle(endAngle))
                        .stroke(
                            entry.category?.color ?? Color(.systemGray),
                            style: StrokeStyle(lineWidth: 20, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                }

                // Center label
                VStack(spacing: 2) {
                    Text(totalTracked)
                        .font(.system(size: 26, weight: .semibold))
                        .monospacedDigit()
                    Text("TRACKED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .frame(width: 190, height: 190)

            // Legend
            FlowLayout(spacing: 12) {
                ForEach(legendItems, id: \.name) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 6, height: 6)
                        Text(item.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }
        }
        .card()
    }

    private func angleForTime(_ date: Date) -> Double {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        return (Double(hour) + Double(minute) / 60.0) / 24.0 * 360.0
    }

    private func normalizeAngle(_ degrees: Double) -> CGFloat {
        CGFloat(degrees / 360.0)
    }
}

// MARK: - Timeline Section

private struct TimelineSection: View {
    let entries: [TimeEntry]

    private var sortedEntries: [TimeEntry] {
        entries
            .filter { $0.category?.name != "Stationary" }
            .sorted { $0.startDate < $1.startDate }
    }

    private var totalDuration: Double {
        entries.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title
            HStack {
                Text("Timeline")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("See all")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.systemBlue))
            }

            // Horizontal stacked bar
            if totalDuration > 0 {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(sortedEntries, id: \.id) { entry in
                            let proportion = entry.duration / totalDuration
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(entry.category?.color ?? Color(.systemGray))
                                .frame(width: max(geo.size.width * proportion - 1, 2))
                        }
                    }
                }
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }

            // All rows in one grouped card
            VStack(spacing: 0) {
                ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 18)
                    }
                    TimelineRow(entry: entry)
                }
            }
            .card(padding: 0)
        }
    }
}

// MARK: - Timeline Row

private struct TimelineRow: View {
    let entry: TimeEntry

    private var timeRange: String {
        let start = entry.startDate.formatted(date: .omitted, time: .shortened)
        let end = entry.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start)\u{2013}\(end)"
    }

    private var isAW: Bool { entry.sourceRaw == "activityWatch" }
    private var isAIRefined: Bool { entry.metadata["aiRefined"] == "true" }

    var body: some View {
        HStack(spacing: 10) {
            // Color stripe
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(entry.category?.color ?? Color(.systemGray))
                .frame(width: 3, height: 40)

            // Name + meta
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(entry.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    if isAIRefined {
                        Image(systemName: "brain")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(.systemPurple))
                    }
                }
                HStack(spacing: 5) {
                    // Category badge for all entries
                    if let categoryName = entry.category?.name {
                        Text(categoryName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isAIRefined ? Color(.systemPurple) : (entry.category?.color ?? Color(.secondaryLabel)))
                    }
                    Text(timeRange)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Spacer()

            // Duration right-aligned
            Text(entry.durationFormatted)
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color(.label))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Insight Card

private struct InsightCard: View {
    let entries: [TimeEntry]

    private var insightText: String {
        let total = entries.reduce(0) { $0 + $1.durationMinutes }
        if total > 360 {
            return "You've been highly active today with over \(total / 60) hours tracked. Consider scheduling a break."
        } else if total > 120 {
            return "Solid tracking today. Your most active category is building good momentum."
        } else {
            return "Your day is just getting started. Morning routines set the tone for deep focus later."
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon box
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBlue).opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(.systemBlue))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S INSIGHT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color(.systemBlue))

                Text(insightText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBlue).opacity(0.09),
                    Color(.systemGreen).opacity(0.06)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemBlue).opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Sources Row

private struct SourcesRow: View {
    let entries: [TimeEntry]

    private var activeSources: [(name: String, color: Color)] {
        var seen = Set<String>()
        var result: [(name: String, color: Color)] = []

        // Always show known sources
        let sourceMap: [String: String] = [
            "healthKit": "HealthKit",
            "calendar": "Calendar",
            "aniList": "AniList",
            "activityWatch": "ActivityWatch",
            "pocketCasts": "PocketCasts"
        ]

        for entry in entries {
            let raw = entry.sourceRaw
            let displayName = sourceMap[raw] ?? raw.capitalized
            if seen.insert(displayName).inserted {
                result.append((name: displayName, color: Color(.systemGreen)))
            }
        }

        // Fallback if no entries parsed
        if result.isEmpty {
            result = [
                (name: "HealthKit", color: Color(.systemGreen)),
                (name: "Calendar", color: Color(.systemGreen))
            ]
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))

            FlowLayout(spacing: 8) {
                ForEach(activeSources, id: \.name) { source in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(source.color)
                            .frame(width: 6, height: 6)
                        Text(source.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Loading State

private struct LoadingStateView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(Color(.systemBlue).opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color(.systemBlue).opacity(0.6))
                        .rotationEffect(.degrees(pulse ? 360 : 0))
                }
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        pulse = true
                    }
                }

            Text("Loading your day...")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}
