import SwiftUI

// MARK: - Sources Row

struct SourcesRow: View {
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

// MARK: - Category Pill

struct CategoryPill: View {
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

// MARK: - Loading State

struct DashboardLoadingView: View {
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

#Preview("Sources Row") {
    SourcesRow(entries: [])
        .padding()
}

#Preview("Category Pill") {
    CategoryPill(name: "Deep Work", color: .blue)
        .padding()
}

#Preview("Loading View") {
    DashboardLoadingView()
}
