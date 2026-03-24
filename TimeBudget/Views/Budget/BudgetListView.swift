import SwiftUI
import SwiftData

struct BudgetListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = BudgetViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    if viewModel.budgets.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.clock",
                            title: "No Budgets Yet",
                            subtitle: "Set time budgets for your categories to track how you spend your day"
                        )
                        .padding(.top, 60)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(viewModel.budgets.enumerated()), id: \.element.id) { index, budget in
                                BudgetRow(
                                    budget: budget,
                                    actualMinutes: viewModel.actualMinutes[budget.categoryName] ?? 0
                                )
                                .slideUpAppear(index: index)
                                .padding(.horizontal, 16)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Haptics.medium()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            viewModel.deleteBudget(budget, context: modelContext)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }

                            Spacer().frame(height: 90)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color(.systemBlue))
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                BudgetEditView { categoryName, targetMinutes, allowRollover in
                    viewModel.saveBudget(
                        categoryName: categoryName,
                        targetMinutes: targetMinutes,
                        allowRollover: allowRollover,
                        context: modelContext
                    )
                }
            }
            .onAppear {
                viewModel.loadBudgets(context: modelContext)
            }
        }
    }
}

struct BudgetRow: View {
    let budget: TimeBudgetModel
    let actualMinutes: Int

    private var progress: Double {
        budget.progress(actualMinutes: actualMinutes)
    }

    private var progressColor: Color {
        if progress >= 1.0 { return Color(.systemRed) }
        if progress >= 0.8 { return Color(.systemOrange) }
        return Color(.systemGreen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(progressColor)
                        .frame(width: 9, height: 9)

                    Text(budget.categoryName)
                        .font(.headline)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(formatMinutes(actualMinutes))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()

                    Text("/ \(budget.targetFormatted)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            // Progress bar — 4pt capsule on separator track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.separator))
                        .frame(height: 4)

                    Capsule()
                        .fill(progressColor)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 4)
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 4)

            // Footer
            HStack {
                if budget.allowRollover && budget.rolloverMinutes > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.forward.circle")
                            .font(.caption2)
                        Text("+\(formatMinutes(budget.rolloverMinutes)) rollover")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                if progress >= 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Over budget")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color(.systemRed))
                } else {
                    Text("\(Int((1.0 - progress) * 100))% remaining")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
        }
        .card()
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
