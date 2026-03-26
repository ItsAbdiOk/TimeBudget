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

#Preview {
    SettingsView()
}
