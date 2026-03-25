import SwiftUI

@available(iOS 26, *)
struct IntelligenceSettingsView: View {
    @AppStorage("intelligence_categorization_enabled") private var categorizationEnabled = true
    @AppStorage("intelligence_conflicts_enabled") private var conflictsEnabled = true
    @AppStorage("intelligence_last_categorization") private var lastCategorizationTimestamp: Double = 0
    @AppStorage("intelligence_last_refined_count") private var lastRefinedCount: Int = 0
    @State private var smokeTestResult: String?
    @State private var smokeTestError: String?
    @State private var isTesting = false
    @State private var refinementLog: [RefinementEntry] = []

    private let accentColor = Color(.systemPurple)

    struct RefinementEntry: Identifiable {
        let id = UUID()
        let app: String
        let site: String
        let from: String
        let to: String
        let confidence: String
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Status card
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(accentColor)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "brain")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("On-Device Intelligence")
                                    .font(.subheadline.weight(.medium))
                                Text("Powered by Apple Intelligence")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Spacer()
                        }
                        .padding(14)

                        Divider().padding(.leading, 52)

                        // Smoke test
                        HStack {
                            if let result = smokeTestResult {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(.systemGreen))
                                        .font(.caption)
                                    Text(result)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(Color(.secondaryLabel))
                                        .lineLimit(3)
                                }
                            } else if let error = smokeTestError {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color(.systemRed))
                                        .font(.caption)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(Color(.systemRed))
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Button {
                                Task { await runSmokeTest() }
                            } label: {
                                HStack(spacing: 6) {
                                    if isTesting {
                                        ProgressView()
                                            .controlSize(.mini)
                                            .tint(.white)
                                    }
                                    Text("Test Model")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(accentColor)
                                .clipShape(Capsule())
                            }
                            .disabled(isTesting)
                        }
                        .padding(14)
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                    .padding(.horizontal, 16)

                    // Feature toggles
                    VStack(spacing: 0) {
                        Toggle(isOn: $categorizationEnabled) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color(.systemBlue))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "tag.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Smart Categorization")
                                        .font(.subheadline.weight(.medium))
                                    Text("Classify all desktop activity with AI")
                                        .font(.caption)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                            }
                        }
                        .tint(accentColor)
                        .padding(14)

                        Divider().padding(.leading, 52)

                        Toggle(isOn: $conflictsEnabled) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color(.systemOrange))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "arrow.triangle.merge")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Conflict Resolution")
                                        .font(.subheadline.weight(.medium))
                                    Text("Resolve overlapping time entries")
                                        .font(.caption)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                            }
                        }
                        .tint(accentColor)
                        .padding(14)
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                    .padding(.horizontal, 16)

                    // Last run stats
                    if lastCategorizationTimestamp > 0 {
                        lastRunCard
                            .padding(.horizontal, 16)
                    }

                    // AI Activity Log
                    if !refinementLog.isEmpty {
                        activityLogCard
                            .padding(.horizontal, 16)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How it works", systemImage: "info.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accentColor)

                        Text("Apple Intelligence runs entirely on-device using the Foundation Models framework. Your data never leaves your iPhone.\n\n**Smart Categorization** uses the on-device LLM to classify all desktop activity — including Chrome URLs from the ActivityWatch extension.\n\n**Conflict Resolution** intelligently resolves overlapping entries — for example, choosing \"Deep Work\" over \"Podcast\" when you're coding with headphones on.")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(accentColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Apple Intelligence")
        .onAppear { loadRefinementLog() }
    }

    // MARK: - Last Run Card

    private var lastRunCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(.systemGreen))
                        .frame(width: 30, height: 30)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Last Categorization")
                        .font(.subheadline.weight(.medium))
                    Text(lastRunTimeString)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                if lastRefinedCount > 0 {
                    Text("\(lastRefinedCount) refined")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                }
            }
            .padding(14)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
    }

    private var lastRunTimeString: String {
        let date = Date(timeIntervalSince1970: lastCategorizationTimestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Activity Log Card

    private var activityLogCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("AI ACTIVITY LOG")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .tracking(0.5)

                Spacer()

                Text("\(refinementLog.count) changes")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.bottom, 12)

            ForEach(Array(refinementLog.prefix(20).enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Divider()
                }
                HStack(spacing: 10) {
                    Image(systemName: "brain")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.site.isEmpty ? entry.app : entry.site)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(entry.from)
                                .font(.system(size: 11))
                                .foregroundStyle(Color(.systemOrange))
                                .strikethrough()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color(.tertiaryLabel))

                            Text(entry.to)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }
                    }

                    Spacer()

                    Text(entry.confidence)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.vertical, 6)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
    }

    // MARK: - Actions

    private func runSmokeTest() async {
        isTesting = true
        smokeTestResult = nil
        smokeTestError = nil

        do {
            let result = try await IntelligenceService.shared.smokeTest()
            await MainActor.run {
                smokeTestResult = result
                isTesting = false
                Haptics.success()
            }
        } catch {
            await MainActor.run {
                smokeTestError = error.localizedDescription
                isTesting = false
            }
        }
    }

    private func loadRefinementLog() {
        guard let logString = UserDefaults.standard.string(forKey: "intelligence_last_refinement_log"),
              let data = logString.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return
        }

        refinementLog = items.map { item in
            RefinementEntry(
                app: item["app"] ?? "",
                site: item["site"] ?? "",
                from: item["from"] ?? "",
                to: item["to"] ?? "",
                confidence: item["confidence"] ?? ""
            )
        }
    }
}
