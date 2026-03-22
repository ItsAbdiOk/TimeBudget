import SwiftUI

struct SettingsView: View {
    @State private var locationService = LocationService.shared
    @State private var calendarService = CalendarService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // Tracking section
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "mappin.circle.fill",
                                iconColor: .blue,
                                title: "My Places",
                                destination: AnyView(PlaceManagementView())
                            )

                            Divider().padding(.leading, 52)

                            SettingsRow(
                                icon: "star.circle.fill",
                                iconColor: .yellow,
                                title: "Ideal Day",
                                destination: AnyView(IdealDaySetupView())
                            )

                            Divider().padding(.leading, 52)

                            SettingsRow(
                                icon: "hand.raised.fill",
                                iconColor: .green,
                                title: "Permissions",
                                destination: AnyView(PermissionsView())
                            )
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)

                        // Connected Accounts
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "book.fill",
                                iconColor: Color(hex: "#AC8E68"),
                                title: "AniList",
                                destination: AnyView(AniListSettingsView())
                            )

                            Divider().padding(.leading, 52)

                            SettingsRow(
                                icon: "chevron.left.forwardslash.chevron.right",
                                iconColor: Color(hex: "#FFA116"),
                                title: "LeetCode",
                                destination: AnyView(LeetCodeSettingsView())
                            )
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)

                        // Data section
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "square.and.arrow.up",
                                iconColor: .indigo,
                                title: "Export Data",
                                destination: AnyView(
                                    VStack {
                                        EmptyStateView(
                                            icon: "square.and.arrow.up",
                                            title: "Export coming soon",
                                            subtitle: "CSV and JSON export will be available in a future update"
                                        )
                                    }
                                    .background(Color(.systemGroupedBackground))
                                )
                            )
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)

                        // About section
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.gray.opacity(0.12))
                                        .frame(width: 32, height: 32)

                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.gray)
                                }

                                Text("Version")
                                    .font(.subheadline)

                                Spacer()

                                Text("1.0")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 90)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let destination: AnyView

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permissions View

struct PermissionsView: View {
    @State private var locationService = LocationService.shared
    @State private var calendarService = CalendarService.shared
    @State private var healthKitService = HealthKitService.shared

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        PermissionRow(
                            title: "Health Data",
                            subtitle: "Sleep, workouts, steps, calories",
                            icon: "heart.fill",
                            color: .red,
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
                            color: .blue,
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
                            color: .orange,
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
                            color: .green,
                            isGranted: MotionService.shared.isAvailable
                        ) {
                            Haptics.light()
                            Task { await MotionService.shared.fetchCurrentActivity() }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    Text("You can also manage permissions in\nSettings > Privacy & Security")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Permissions")
    }
}

// MARK: - AniList Settings

struct AniListSettingsView: View {
    @AppStorage("anilist_username") private var username = ""
    @AppStorage("anilist_minutes_per_chapter") private var minutesPerChapter = 4

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(hex: "#AC8E68").opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#AC8E68"))
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Username")
                                    .font(.subheadline.weight(.medium))
                                Text("Your AniList profile name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            TextField("Username", text: $username)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 140)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(14)

                        Divider().padding(.leading, 52)

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(hex: "#AC8E68").opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#AC8E68"))
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Minutes per Chapter")
                                    .font(.subheadline.weight(.medium))
                                Text("Average reading time")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Stepper("\(minutesPerChapter) min", value: $minutesPerChapter, in: 1...30)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    if !username.isEmpty {
                        Text("Tracking manga reading for **\(username)**")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Enter your AniList username to track manga reading")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("AniList")
    }
}

// MARK: - LeetCode Settings

struct LeetCodeSettingsView: View {
    @AppStorage("leetcode_username") private var username = ""

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(hex: "#FFA116").opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#FFA116"))
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Username")
                                    .font(.subheadline.weight(.medium))
                                Text("Your LeetCode profile name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            TextField("Username", text: $username)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 140)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(14)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    if !username.isEmpty {
                        Text("Tracking submissions for **\(username)**")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Enter your LeetCode username to track coding practice")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("LeetCode")
    }
}

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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
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
