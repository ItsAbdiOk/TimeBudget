import SwiftUI

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

#Preview {
    NavigationStack {
        LeetCodeSettingsView()
    }
}
