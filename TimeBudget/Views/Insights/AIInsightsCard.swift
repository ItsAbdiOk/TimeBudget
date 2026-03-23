import SwiftUI
import SwiftData

// MARK: - AI Insights Card

/// Shows the LLM-generated daily narrative in the Insights tab.
/// Handles loading / error / empty states and lets the user regenerate.
struct AIInsightsCard: View {
    let narrative: String?
    let suggestion: String?
    let isGenerating: Bool
    let error: String?
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.purple)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("AI SUMMARY")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)

                    Text("Today at a glance")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }

                Spacer()

                Button {
                    Haptics.light()
                    onRegenerate()
                } label: {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.purple)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.purple)
                    }
                }
                .disabled(isGenerating)
            }

            Divider()

            // Body
            if isGenerating {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.purple)
                    Text("Analysing your day…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

            } else if let errorMsg = error {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                    Text(errorMsg)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

            } else if let text = narrative, !text.isEmpty {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let tip = suggestion, !tip.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text(tip)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color.yellow.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

            } else {
                Text("Tap the refresh button to generate an AI summary of your day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}
