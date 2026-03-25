import SwiftUI

struct PocketCastsLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var statusResult: TestResult?

    private let service = PocketCastsService.shared
    private let brandColor = Color(hex: "#F43F5E")

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Apple Wallet-style card
                        VStack(spacing: 0) {
                            // Branded header strip
                            HStack(spacing: 10) {
                                Image(systemName: "headphones")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Pocket Casts")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(brandColor)

                            // Form body
                            VStack(spacing: 0) {
                                // Email row
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(brandColor)
                                            .frame(width: 30, height: 30)
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }

                                    Text("Email")
                                        .font(.subheadline.weight(.medium))

                                    Spacer()

                                    TextField("you@example.com", text: $email)
                                        .font(.subheadline)
                                        .foregroundStyle(Color(.secondaryLabel))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 180)
                                        .keyboardType(.emailAddress)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                }
                                .padding(14)

                                Divider().padding(.leading, 52)

                                // Password row
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(brandColor)
                                            .frame(width: 30, height: 30)
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }

                                    Text("Password")
                                        .font(.subheadline.weight(.medium))

                                    Spacer()

                                    SecureField("Password", text: $password)
                                        .font(.subheadline)
                                        .foregroundStyle(Color(.secondaryLabel))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 180)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                }
                                .padding(14)

                                Divider().padding(.leading, 52)

                                // Sign In button
                                Button {
                                    Task { await login() }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isLoggingIn {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(.white)
                                        }
                                        Text("Sign In")
                                            .font(.headline)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(canLogin ? brandColor : Color(.systemGray3))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .disabled(!canLogin || isLoggingIn)
                                .padding(14)
                            }
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
                        .padding(.horizontal, 16)

                        // Status message
                        if let result = statusResult {
                            HStack(spacing: 8) {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.success ? Color(.systemGreen) : Color(.systemRed))
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundStyle(result.success ? Color(.secondaryLabel) : Color(.systemRed))
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Text("Sign in with your Pocket Casts account to track podcast listening.")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: statusResult?.message)
        }
    }

    private var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private func login() async {
        isLoggingIn = true
        statusResult = nil

        do {
            let loggedInEmail = try await service.login(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
            await MainActor.run {
                email = ""
                password = ""
                statusResult = TestResult(success: true, message: "Signed in as \(loggedInEmail)")
                isLoggingIn = false
                Haptics.success()
            }
            // Auto-dismiss after brief delay to show success
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                let message: String
                if case PocketCastsError.unauthorized = error {
                    message = "Incorrect email or password"
                } else {
                    message = error.localizedDescription
                }
                statusResult = TestResult(success: false, message: message)
                isLoggingIn = false
            }
        }
    }
}
