import SwiftUI
import SwiftData

struct IdealDaySetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var idealTargets: [IdealDay]

    private let categories = [
        ("Sleep", "moon.zzz.fill", "#5E5CE6"),
        ("Exercise", "figure.run", "#30D158"),
        ("Work", "briefcase.fill", "#0A84FF"),
        ("Deep Work", "brain.head.profile", "#FF375F"),
        ("Meetings", "person.2.fill", "#BF5AF2"),
        ("Commute", "car.fill", "#FF6482"),
        ("Reading", "book.fill", "#AC8E68"),
        ("Creative", "paintbrush.fill", "#FF9F0A"),
    ]

    @State private var targets: [String: Double] = [:]
    @State private var hasLoaded = false

    var totalMinutes: Int {
        targets.values.reduce(0) { $0 + Int($1) }
    }

    var totalFormatted: String {
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return "\(hours)h \(mins)m"
    }

    var isOverDay: Bool {
        totalMinutes > 1440
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    // Total summary card
                    VStack(spacing: 8) {
                        HStack {
                            Text("Total")
                                .font(.system(.headline, design: .default))
                            Spacer()
                            HStack(spacing: 4) {
                                Text(totalFormatted)
                                    .font(.system(.title3, design: .default).weight(.bold).monospacedDigit())
                                    .foregroundStyle(isOverDay ? Color(.systemRed) : Color(.label))
                                Text("/ 24h")
                                    .font(.system(.subheadline, design: .default).monospacedDigit())
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        }

                        // Visual bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(.separator))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(isOverDay ? Color(.systemRed) : Color(.systemBlue))
                                    .frame(width: geo.size.width * min(Double(totalMinutes) / 1440.0, 1.0), height: 8)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: totalMinutes)
                            }
                        }
                        .frame(height: 8)

                        if isOverDay {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                Text("Your ideal day exceeds 24 hours")
                                    .font(.caption)
                            }
                            .foregroundStyle(Color(.systemRed))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .card()
                    .padding(.horizontal, 16)

                    // Category sliders
                    ForEach(categories, id: \.0) { name, icon, colorHex in
                        VStack(spacing: 10) {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(Color(hex: colorHex).opacity(0.12))
                                        .frame(width: 38, height: 38)

                                    Image(systemName: icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color(hex: colorHex))
                                }

                                Text(name)
                                    .font(.subheadline.weight(.medium))

                                Spacer()

                                Text(formatMinutes(Int(targets[name] ?? 0)))
                                    .font(.system(.subheadline, design: .default).weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Slider(
                                value: Binding(
                                    get: { targets[name] ?? 0 },
                                    set: { targets[name] = $0 }
                                ),
                                in: 0...480,
                                step: 15
                            ) { editing in
                                if !editing { Haptics.light() }
                            }
                            .tint(Color(hex: colorHex))
                        }
                        .card()
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Ideal Day")
        .onAppear {
            if !hasLoaded {
                loadTargets()
                hasLoaded = true
            }
        }
        .onDisappear {
            saveTargets()
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
    }

    private func loadTargets() {
        for target in idealTargets {
            targets[target.categoryName] = Double(target.targetMinutes)
        }
    }

    private func saveTargets() {
        for target in idealTargets {
            modelContext.delete(target)
        }

        for (name, minutes) in targets where Int(minutes) > 0 {
            let target = IdealDay(categoryName: name, targetMinutes: Int(minutes))
            modelContext.insert(target)
        }

        try? modelContext.save()
    }
}
