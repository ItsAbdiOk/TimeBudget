import SwiftUI
import SwiftData

struct BudgetListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = BudgetViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

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
                            .foregroundStyle(.blue)
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
        if progress >= 1.0 { return .red }
        if progress >= 0.8 { return .orange }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text(budget.categoryName)
                    .font(.system(.headline, design: .rounded))

                Spacer()

                HStack(spacing: 4) {
                    Text(formatMinutes(actualMinutes))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())

                    Text("/ \(budget.targetFormatted)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(progressColor.opacity(0.12))
                        .frame(height: 10)

                    Capsule()
                        .fill(progressColor)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 10)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 10)

            // Footer
            HStack {
                if budget.allowRollover && budget.rolloverMinutes > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.forward.circle")
                            .font(.caption2)
                        Text("+\(formatMinutes(budget.rolloverMinutes)) rollover")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if progress >= 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Over budget")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.red)
                } else {
                    Text("\(Int((1.0 - progress) * 100))% remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
