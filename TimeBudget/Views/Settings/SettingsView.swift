import SwiftUI

struct SettingsView: View {
    @State private var locationService = LocationService.shared
    @State private var calendarService = CalendarService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // Tracking section
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "mappin.circle.fill",
                                iconColor: Color(.systemBlue),
                                title: "My Places",
                                destination: AnyView(PlaceManagementView())
                            )

                            Divider().padding(.leading, 52)

                            SettingsRow(
                                icon: "star.circle.fill",
                                iconColor: Color(.systemYellow),
                                title: "Ideal Day",
                                destination: AnyView(IdealDaySetupView())
                            )

                            Divider().padding(.leading, 52)

                            SettingsRow(
                                icon: "hand.raised.fill",
                                iconColor: Color(.systemGreen),
                                title: "Permissions",
                                destination: AnyView(PermissionsView())
                            )
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
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

                            Divider().padding(.leading, 52)

                            SettingsRow(
                                icon: "headphones",
                                iconColor: Color(hex: "#F43F5E"),
                                title: "Pocket Casts",
                                destination: AnyView(PocketCastsSettingsView())
                            )

                            Divider().padding(.leading, 52)

                            SettingsRow(
                                icon: "desktopcomputer",
                                iconColor: Color(hex: "#8B5CF6"),
                                title: "ActivityWatch",
                                destination: AnyView(ActivityWatchSettingsView())
                            )
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                        .padding(.horizontal, 16)

                        // Intelligence
                        if #available(iOS 26, *) {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "brain",
                                    iconColor: Color(.systemPurple),
                                    title: "Apple Intelligence",
                                    destination: AnyView(IntelligenceSettingsView())
                                )
                            }
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                            .padding(.horizontal, 16)
                        }

                        // Data section
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "square.and.arrow.up",
                                iconColor: Color(.systemIndigo),
                                title: "Export Data",
                                destination: AnyView(
                                    VStack {
                                        EmptyStateView(
                                            icon: "square.and.arrow.up",
                                            title: "Export coming soon",
                                            subtitle: "CSV and JSON export will be available in a future update"
                                        )
                                    }
                                    .background(Color(.systemBackground))
                                )
                            )
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                        .padding(.horizontal, 16)

                        // About section
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color(.systemGray))
                                        .frame(width: 30, height: 30)

                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                }

                                Text("Version")
                                    .font(.subheadline)

                                Spacer()

                                Text("1.0")
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                            .padding(14)
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
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
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor)
                        .frame(width: 30, height: 30)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
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

// MARK: - AniList Settings

struct AniListSettingsView: View {
    @AppStorage("anilist_username") private var username = ""
    @AppStorage("anilist_minutes_per_chapter") private var minutesPerChapter = 4

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(hex: "#AC8E68"))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Username")
                                    .font(.subheadline.weight(.medium))
                                Text("Your AniList profile name")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Spacer()

                            TextField("Username", text: $username)
                                .font(.subheadline)
                                .foregroundStyle(Color(.secondaryLabel))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 140)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(14)

                        Divider().padding(.leading, 52)

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(hex: "#AC8E68"))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Minutes per Chapter")
                                    .font(.subheadline.weight(.medium))
                                Text("Average reading time")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Spacer()

                            Stepper("\(minutesPerChapter) min", value: $minutesPerChapter, in: 1...30)
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        .padding(14)
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                    .padding(.horizontal, 16)

                    if !username.isEmpty {
                        Text("Tracking manga reading for **\(username)**")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    } else {
                        Text("Enter your AniList username to track manga reading")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
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
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(hex: "#FFA116"))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Username")
                                    .font(.subheadline.weight(.medium))
                                Text("Your LeetCode profile name")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Spacer()

                            TextField("Username", text: $username)
                                .font(.subheadline)
                                .foregroundStyle(Color(.secondaryLabel))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 140)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(14)
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                    .padding(.horizontal, 16)

                    if !username.isEmpty {
                        Text("Tracking submissions for **\(username)**")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    } else {
                        Text("Enter your LeetCode username to track coding practice")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
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
