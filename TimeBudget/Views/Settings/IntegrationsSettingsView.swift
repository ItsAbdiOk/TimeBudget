import SwiftUI

// MARK: - Pocket Casts Settings

struct PocketCastsSettingsView: View {
    @State private var tokenInput = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var hasToken: Bool

    private let service = PocketCastsService.shared

    init() {
        _hasToken = State(initialValue: PocketCastsService.shared.isConfigured)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Info card
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How to get your token", systemImage: "info.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)

                        Text("1. Open **play.pocketcasts.com** in a browser\n2. Log in to your account\n3. Open Developer Tools (F12)\n4. Go to **Application** > **Local Storage**\n5. Copy the value of the **token** key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)

                    // Token input card
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.red.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.red)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Bearer Token")
                                        .font(.subheadline.weight(.medium))
                                    Text(hasToken ? "Token saved securely in Keychain" : "Paste your token below")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if hasToken {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }

                            SecureField("Paste bearer token here", text: $tokenInput)
                                .font(.system(.caption, design: .monospaced))
                                .padding(10)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(14)

                        Divider().padding(.leading, 52)

                        // Actions row
                        HStack(spacing: 12) {
                            if hasToken {
                                Button {
                                    Haptics.light()
                                    service.clearToken()
                                    hasToken = false
                                    tokenInput = ""
                                    testResult = nil
                                } label: {
                                    Text("Remove")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.red.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }

                            Spacer()

                            if !tokenInput.isEmpty {
                                Button {
                                    Haptics.light()
                                    service.saveToken(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines))
                                    hasToken = true
                                    tokenInput = ""
                                } label: {
                                    Text("Save Token")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .clipShape(Capsule())
                                }
                            }

                            Button {
                                Task { await testPocketCasts() }
                            } label: {
                                HStack(spacing: 4) {
                                    if isTesting {
                                        ProgressView()
                                            .controlSize(.mini)
                                    }
                                    Text("Test Connection")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(hasToken ? Color.green : Color.gray)
                                .clipShape(Capsule())
                            }
                            .disabled(!hasToken || isTesting)
                        }
                        .padding(14)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    // Test result
                    if let result = testResult {
                        HStack(spacing: 8) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.success ? .green : .red)
                            Text(result.message)
                                .font(.caption)
                                .foregroundStyle(result.success ? .secondary : .red)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Pocket Casts")
        .animation(.easeInOut(duration: 0.2), value: testResult?.message)
    }

    private func testPocketCasts() async {
        isTesting = true
        testResult = nil

        do {
            let success = try await service.testConnection()
            await MainActor.run {
                testResult = TestResult(success: success, message: success ? "Connected successfully" : "Connection failed")
                isTesting = false
            }
        } catch {
            await MainActor.run {
                testResult = TestResult(success: false, message: error.localizedDescription)
                isTesting = false
            }
        }
    }
}

// MARK: - ActivityWatch Settings

struct ActivityWatchSettingsView: View {
    @AppStorage("activitywatch_ip") private var desktopIP = ""
    @AppStorage("activitywatch_hostname") private var hostname = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?

    private let service = ActivityWatchService.shared

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Info card
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Setup", systemImage: "info.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.purple)

                        Text("ActivityWatch must be running on your desktop. Your iPhone must be on the same WiFi network to connect.\n\n**IP Address:** Find it in System Settings > Network\n**Hostname:** Your computer name (e.g. MacBook-Pro)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.purple.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)

                    // Config card
                    VStack(spacing: 0) {
                        // IP Address row
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.purple.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "network")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.purple)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Desktop IP")
                                    .font(.subheadline.weight(.medium))
                                Text("Local network address")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            TextField("192.168.1.50", text: $desktopIP)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 150)
                                .keyboardType(.decimalPad)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(14)

                        Divider().padding(.leading, 52)

                        // Hostname row
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.purple.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "desktopcomputer")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.purple)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Hostname")
                                    .font(.subheadline.weight(.medium))
                                Text("Computer name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            TextField("MacBook-Pro", text: $hostname)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 150)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(14)

                        Divider().padding(.leading, 52)

                        // Test connection
                        HStack {
                            Spacer()

                            Button {
                                Task { await testActivityWatch() }
                            } label: {
                                HStack(spacing: 4) {
                                    if isTesting {
                                        ProgressView()
                                            .controlSize(.mini)
                                    }
                                    Text("Test Connection")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(service.isConfigured ? Color.purple : Color.gray)
                                .clipShape(Capsule())
                            }
                            .disabled(!service.isConfigured || isTesting)
                        }
                        .padding(14)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    // Test result
                    if let result = testResult {
                        HStack(spacing: 8) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.success ? .green : .red)
                            Text(result.message)
                                .font(.caption)
                                .foregroundStyle(result.success ? .secondary : .red)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Status
                    if service.isConfigured {
                        VStack(spacing: 4) {
                            Text("Bucket: aw-watcher-window_\(hostname)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Text("http://\(desktopIP):5600")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("ActivityWatch")
        .animation(.easeInOut(duration: 0.2), value: testResult?.message)
    }

    private func testActivityWatch() async {
        isTesting = true
        testResult = nil

        do {
            let success = try await service.testConnection()
            await MainActor.run {
                testResult = TestResult(success: success, message: success ? "Connected to ActivityWatch" : "Connection failed")
                isTesting = false
            }
        } catch {
            await MainActor.run {
                let message: String
                if case ActivityWatchError.unreachable = error {
                    message = "Cannot reach \(desktopIP):5600. Make sure ActivityWatch is running and you're on the same WiFi."
                } else if case ActivityWatchError.noBucket = error {
                    message = "Server found but bucket 'aw-watcher-window_\(hostname)' not found. Check hostname."
                } else {
                    message = error.localizedDescription
                }
                testResult = TestResult(success: false, message: message)
                isTesting = false
            }
        }
    }
}

// MARK: - Shared

struct TestResult {
    let success: Bool
    let message: String
}
