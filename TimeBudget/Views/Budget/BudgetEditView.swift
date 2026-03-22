import SwiftUI

struct BudgetEditView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (String, Int, Bool) -> Void

    @State private var selectedCategory = "Sleep"
    @State private var targetMinutes: Double = 60
    @State private var allowRollover = false

    private let categories = [
        ("Sleep", "moon.zzz.fill", Color.indigo),
        ("Exercise", "figure.run", Color.green),
        ("Work", "briefcase.fill", Color.blue),
        ("Deep Work", "brain.head.profile", Color.pink),
        ("Meetings", "person.2.fill", Color.purple),
        ("Commute", "car.fill", Color.pink),
        ("Reading", "book.fill", Color(hex: "#AC8E68")),
        ("Creative", "paintbrush.fill", Color.orange),
        ("Walking", "figure.walk", Color.cyan),
        ("Stationary", "figure.stand", Color.gray),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Category picker
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Category")

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                            ], spacing: 8) {
                                ForEach(categories, id: \.0) { name, icon, color in
                                    Button {
                                        Haptics.selection()
                                        selectedCategory = name
                                    } label: {
                                        VStack(spacing: 6) {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedCategory == name ? color.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                                                    .frame(width: 44, height: 44)

                                                Image(systemName: icon)
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(selectedCategory == name ? color : .secondary)
                                            }

                                            Text(name)
                                                .font(.system(size: 9, weight: selectedCategory == name ? .semibold : .regular))
                                                .foregroundStyle(selectedCategory == name ? .primary : .secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .card()

                        // Target slider
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Daily Target")

                            Text(formatMinutes(Int(targetMinutes)))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .center)

                            Slider(value: $targetMinutes, in: 15...720, step: 15) { editing in
                                if !editing { Haptics.light() }
                            }
                            .tint(.blue)
                        }
                        .card()

                        // Rollover toggle
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Allow Rollover")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Unused minutes carry to the next day")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: $allowRollover)
                                    .labelsHidden()
                                    .onChange(of: allowRollover) { _, _ in
                                        Haptics.light()
                                    }
                            }
                        }
                        .card()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.light()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.success()
                        onSave(selectedCategory, Int(targetMinutes), allowRollover)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
