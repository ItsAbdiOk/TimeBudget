import SwiftUI
import SwiftData

struct FocusStopwatchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FocusViewModel()

    private let focusCategories = [
        ("Manga", "book.fill", Color(hex: "#AC8E68")),
        ("Leetcode", "chevron.left.forwardslash.chevron.right", Color(hex: "#FFA116")),
        ("Learning", "brain.head.profile", Color(hex: "#AF52DE")),
        ("Coding", "laptopcomputer", Color(hex: "#0A84FF")),
        ("Yoga", "figure.yoga", Color(hex: "#30D158")),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 32)

                        // Timer ring + display
                        TimerDisplay(
                            elapsed: viewModel.elapsedFormatted,
                            isRunning: viewModel.isRunning,
                            category: viewModel.selectedCategory,
                            categoryColor: colorFor(viewModel.selectedCategory)
                        )

                        Spacer().frame(height: 40)

                        // Category picker (when stopped)
                        if !viewModel.isRunning {
                            CategoryPicker(
                                categories: focusCategories,
                                selected: $viewModel.selectedCategory
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .padding(.horizontal, 16)
                        }

                        Spacer().frame(height: 32)

                        // Control buttons
                        ControlButtons(
                            isRunning: viewModel.isRunning,
                            onStart: {
                                Haptics.medium()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.start(context: modelContext)
                                }
                            },
                            onStop: {
                                Haptics.heavy()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.stop(context: modelContext)
                                }
                            },
                            onDiscard: {
                                Haptics.light()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.discard(context: modelContext)
                                }
                            }
                        )

                        Spacer().frame(height: 24)

                        // Recent sessions
                        if !viewModel.recentSessions.isEmpty && !viewModel.isRunning {
                            RecentSessionsList(
                                sessions: Array(viewModel.recentSessions.prefix(5)),
                                colorForCategory: colorFor
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // Bottom spacer for tab bar
                        Spacer().frame(height: 90)
                    }
                    .frame(minHeight: UIScreen.main.bounds.height - 100)
                }
            }
            .navigationTitle("Focus")
            .onAppear {
                viewModel.resumeIfNeeded(context: modelContext)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isRunning)
        }
    }

    private func colorFor(_ category: String) -> Color {
        focusCategories.first(where: { $0.0 == category })?.2 ?? Color(.systemGray)
    }
}

// MARK: - Timer Display

private struct TimerDisplay: View {
    let elapsed: String
    let isRunning: Bool
    let category: String
    let categoryColor: Color
    @State private var ringProgress: CGFloat = 0

    var body: some View {
        ZStack {
            // Background track ring
            Circle()
                .stroke(Color(.separator), lineWidth: 6)
                .frame(width: 240, height: 240)

            // Animated ring when running
            if isRunning {
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        categoryColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .onAppear {
                        withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                            ringProgress = 1.0
                        }
                    }
                    .onDisappear { ringProgress = 0 }
            }

            VStack(spacing: 8) {
                Text(elapsed)
                    .font(.system(size: 56, weight: .light))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.1), value: elapsed)

                if isRunning {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(categoryColor)
                            .frame(width: 6, height: 6)

                        Text(category)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Category Picker

private struct CategoryPicker: View {
    let categories: [(String, String, Color)]
    @Binding var selected: String

    var body: some View {
        VStack(spacing: 14) {
            Text("What are you focusing on?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(.secondaryLabel))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                ForEach(categories, id: \.0) { name, icon, color in
                    Button {
                        Haptics.selection()
                        selected = name
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(selected == name ? color.opacity(0.15) : Color(.tertiarySystemBackground))
                                    .frame(width: 38, height: 38)

                                Image(systemName: icon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(selected == name ? color : Color(.secondaryLabel))
                            }

                            Text(name)
                                .font(.caption2.weight(selected == name ? .semibold : .regular))
                                .foregroundStyle(selected == name ? Color(.label) : Color(.secondaryLabel))
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected == name ? color.opacity(0.06) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected == name ? color.opacity(0.3) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Control Buttons

private struct ControlButtons: View {
    let isRunning: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            if isRunning {
                // Discard
                Button(action: onDiscard) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                }
                .buttonStyle(CircleButtonStyle(size: 56, color: Color(.tertiarySystemBackground)))
                .foregroundStyle(Color(.secondaryLabel))
                .transition(.scale.combined(with: .opacity))

                // Stop
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 22, weight: .semibold))
                }
                .buttonStyle(CircleButtonStyle(size: 72, color: Color(.systemRed)))
                .transition(.scale.combined(with: .opacity))
            } else {
                // Start
                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                }
                .buttonStyle(CircleButtonStyle(size: 72, color: Color(.systemGreen)))
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Recent Sessions List

private struct RecentSessionsList: View {
    let sessions: [FocusSession]
    let colorForCategory: (String) -> Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent")
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(colorForCategory(session.categoryName))
                            .frame(width: 3, height: 28)

                        Text(session.categoryName)
                            .font(.system(size: 14, weight: .medium))

                        Spacer()

                        Text(session.durationFormatted)
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Color(.secondaryLabel))

                        Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if session.id != sessions.last?.id {
                        Divider().padding(.leading, 32)
                    }
                }
            }
            .padding(.vertical, 2)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
            .padding(.horizontal, 16)
        }
    }
}
