import SwiftUI

// MARK: - Pocket Casts Settings

struct PocketCastsSettingsView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var statusResult: TestResult?
    @State private var hasToken: Bool

    private let service = PocketCastsService.shared

    init() {
        _hasToken = State(initialValue: PocketCastsService.shared.isConfigured)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if hasToken {
                        // Logged in state
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color(hex: "#F43F5E"))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Connected")
                                        .font(.subheadline.weight(.medium))
                                    Text("Podcast listening is being tracked")
                                        .font(.caption)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }

                                Spacer()
                            }
                            .padding(14)

                            Divider().padding(.leading, 52)

                            HStack {
                                Spacer()

                                Button {
                                    Haptics.light()
                                    service.clearToken()
                                    hasToken = false
                                    statusResult = nil
                                } label: {
                                    Text("Sign Out")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(.systemRed))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemRed).opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(14)
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                        .padding(.horizontal, 16)

                    } else {
                        // Login form
                        VStack(spacing: 0) {
                            // Email row
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color(hex: "#F43F5E"))
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
                                        .fill(Color(hex: "#F43F5E"))
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

                            // Sign in button
                            HStack {
                                Spacer()

                                Button {
                                    Task { await login() }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isLoggingIn {
                                            ProgressView()
                                                .controlSize(.mini)
                                                .tint(.white)
                                        }
                                        Text("Sign In")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(canLogin ? Color(hex: "#F43F5E") : Color(.systemGray))
                                    .clipShape(Capsule())
                                }
                                .disabled(!canLogin || isLoggingIn)
                            }
                            .padding(14)
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                        .padding(.horizontal, 16)
                    }

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

                    if !hasToken {
                        Text("Sign in with your Pocket Casts account to track podcast listening")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Pocket Casts")
        .animation(.easeInOut(duration: 0.2), value: statusResult?.message)
        .animation(.easeInOut(duration: 0.3), value: hasToken)
    }

    private var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
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
                hasToken = true
                email = ""
                password = ""
                statusResult = TestResult(success: true, message: "Signed in as \(loggedInEmail)")
                isLoggingIn = false
                Haptics.success()
            }
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

// MARK: - ActivityWatch Settings

struct ActivityWatchSettingsView: View {
    @AppStorage("activitywatch_ip") private var desktopIP = ""
    @AppStorage("activitywatch_hostname") private var hostname = ""
    @State private var isConnecting = false
    @State private var testResult: TestResult?

    private let service = ActivityWatchService.shared

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Config card — just the IP address
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(hex: "#8B5CF6"))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "network")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Desktop IP")
                                    .font(.subheadline.weight(.medium))
                                Text("System Settings > Network")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Spacer()

                            TextField("192.168.1.50", text: $desktopIP)
                                .font(.system(.subheadline, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(Color(.secondaryLabel))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 150)
                                .keyboardType(.decimalPad)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(14)

                        Divider().padding(.leading, 52)

                        // Connect button — discovers hostname automatically
                        HStack {
                            if !hostname.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(.systemGreen))
                                        .font(.caption)
                                    Text(hostname)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                            }

                            Spacer()

                            Button {
                                Task { await connectAndDiscover() }
                            } label: {
                                HStack(spacing: 6) {
                                    if isConnecting {
                                        ProgressView()
                                            .controlSize(.mini)
                                            .tint(.white)
                                    }
                                    Text(hostname.isEmpty ? "Connect" : "Reconnect")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(!desktopIP.isEmpty ? Color(hex: "#8B5CF6") : Color(.systemGray))
                                .clipShape(Capsule())
                            }
                            .disabled(desktopIP.isEmpty || isConnecting)
                        }
                        .padding(14)
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                    .padding(.horizontal, 16)

                    // Status
                    if let result = testResult {
                        HStack(spacing: 8) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.success ? Color(.systemGreen) : Color(.systemRed))
                            Text(result.message)
                                .font(.caption)
                                .foregroundStyle(result.success ? Color(.secondaryLabel) : Color(.systemRed))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How it works", systemImage: "info.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#8B5CF6"))

                        Text("Enter your desktop's IP address and tap **Connect**. The app will find your ActivityWatch instance and auto-detect the hostname.\n\nYour iPhone must be on the same WiFi network as your desktop.")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color(hex: "#8B5CF6").opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)

                    if hostname.isEmpty {
                        // Disconnect option
                    } else {
                        // Show connected details
                        VStack(spacing: 4) {
                            Text("http://\(desktopIP):5600")
                                .font(.system(.caption2, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(Color(.tertiaryLabel))
                            Text("aw-watcher-window_\(hostname)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }

                        Button {
                            Haptics.light()
                            hostname = ""
                            desktopIP = ""
                            testResult = nil
                        } label: {
                            Text("Disconnect")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(.systemRed))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemRed).opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("ActivityWatch")
        .animation(.easeInOut(duration: 0.2), value: testResult?.message)
        .animation(.easeInOut(duration: 0.3), value: hostname)
    }

    private func connectAndDiscover() async {
        isConnecting = true
        testResult = nil

        do {
            // Step 1: Test connectivity
            _ = try await service.testConnection()

            // Step 2: Auto-discover hostname from buckets
            let discoveredHostname = try await service.discoverHostname()

            await MainActor.run {
                hostname = discoveredHostname
                testResult = TestResult(
                    success: true,
                    message: "Connected! Found hostname: \(discoveredHostname)"
                )
                isConnecting = false
                Haptics.success()
            }
        } catch {
            await MainActor.run {
                let message: String
                if case ActivityWatchError.unreachable = error {
                    message = "Cannot reach \(desktopIP):5600. Make sure ActivityWatch is running and you're on the same WiFi."
                } else if case ActivityWatchError.noBucket = error {
                    message = "Server reached but no window watcher found. Is aw-watcher-window running?"
                } else {
                    message = error.localizedDescription
                }
                testResult = TestResult(success: false, message: message)
                isConnecting = false
            }
        }
    }
}

// MARK: - Shared

struct TestResult {
    let success: Bool
    let message: String
}
