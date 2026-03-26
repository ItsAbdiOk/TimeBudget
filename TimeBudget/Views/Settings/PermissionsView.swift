import SwiftUI

struct PermissionsView: View {
    @State private var locationService = LocationService.shared
    @State private var calendarService = CalendarService.shared
    @State private var healthKitService = HealthKitService.shared

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        PermissionRow(
                            title: "Health Data",
                            subtitle: "Sleep, workouts, steps, calories",
                            icon: "heart.fill",
                            color: Color(.systemRed),
                            isGranted: healthKitService.isAuthorized
                        ) {
                            Haptics.light()
                            Task { try? await healthKitService.requestAuthorization() }
                        }

                        Divider().padding(.leading, 52)

                        PermissionRow(
                            title: "Location",
                            subtitle: "Detect time at saved places",
                            icon: "location.fill",
                            color: Color(.systemBlue),
                            isGranted: locationService.isAuthorized
                        ) {
                            Haptics.light()
                            locationService.requestAuthorization()
                        }

                        Divider().padding(.leading, 52)

                        PermissionRow(
                            title: "Calendar",
                            subtitle: "Track meeting time",
                            icon: "calendar",
                            color: Color(.systemOrange),
                            isGranted: calendarService.isAuthorized
                        ) {
                            Haptics.light()
                            Task { try? await calendarService.requestAuthorization() }
                        }

                        Divider().padding(.leading, 52)

                        PermissionRow(
                            title: "Motion & Fitness",
                            subtitle: "Detect walking, running, driving",
                            icon: "figure.walk",
                            color: Color(.systemGreen),
                            isGranted: MotionService.shared.isAvailable
                        ) {
                            Haptics.light()
                            Task { await MotionService.shared.fetchCurrentActivity() }
                        }
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                    .padding(.horizontal, 16)

                    Text("You can also manage permissions in\nSettings > Privacy & Security")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Permissions")
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color)
                    .frame(width: 30, height: 30)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(.systemGreen))
            } else {
                Button {
                    action()
                } label: {
                    Text("Allow")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(color)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
    }
}

#Preview {
    NavigationStack {
        PermissionsView()
    }
}
