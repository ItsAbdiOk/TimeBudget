import SwiftUI

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

#Preview {
    NavigationStack {
        AniListSettingsView()
    }
}
