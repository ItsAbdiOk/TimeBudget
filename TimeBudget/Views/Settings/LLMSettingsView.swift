import SwiftUI

// MARK: - LLM Settings View

struct LLMSettingsView: View {
    @AppStorage("llm_provider")      private var providerRaw = ""
    @AppStorage("llm_ollama_host")   private var ollamaHost  = ""
    @AppStorage("llm_ollama_model")  private var ollamaModel = ""

    @State private var isTesting = false
    @State private var testResult: TestResult?

    private var provider: LLMProvider? { LLMProvider(rawValue: providerRaw) }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    // Provider picker
                    VStack(spacing: 0) {
                        providerRow(
                            title: "Ollama (local network)",
                            subtitle: "Run a model on your Mac over WiFi",
                            icon: "server.rack",
                            color: Color(hex: "#8B5CF6"),
                            selected: provider == .ollama
                        ) {
                            providerRaw = LLMProvider.ollama.rawValue
                        }

                        Divider().padding(.leading, 52)

                        providerRow(
                            title: "On-device (Apple Intelligence)",
                            subtitle: "iPhone 15 Pro+ · iOS 18.2+ required",
                            icon: "iphone",
                            color: Color(hex: "#06B6D4"),
                            selected: provider == .foundation
                        ) {
                            providerRaw = LLMProvider.foundation.rawValue
                        }

                        if !providerRaw.isEmpty {
                            Divider().padding(.leading, 52)
                            HStack {
                                Spacer()
                                Button {
                                    Haptics.light()
                                    providerRaw = ""
                                    testResult  = nil
                                } label: {
                                    Text("Disable AI Analysis")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.red.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(14)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    // Ollama configuration
                    if provider == .ollama {
                        VStack(spacing: 0) {
                            // Host
                            HStack(spacing: 12) {
                                iconView("network", color: Color(hex: "#8B5CF6"))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Mac IP Address")
                                        .font(.subheadline.weight(.medium))
                                    Text("Same as ActivityWatch")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                TextField("192.168.1.50", text: $ollamaHost)
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

                            // Model
                            HStack(spacing: 12) {
                                iconView("cpu", color: Color(hex: "#8B5CF6"))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Model")
                                        .font(.subheadline.weight(.medium))
                                    Text("Must be pulled in Ollama first")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                TextField("llama3.2:3b", text: $ollamaModel)
                                    .font(.system(.subheadline, design: .monospaced))
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
                                if let result = testResult {
                                    HStack(spacing: 6) {
                                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(result.success ? .green : .red)
                                            .font(.caption)
                                        Text(result.message)
                                            .font(.caption)
                                            .foregroundStyle(result.success ? Color.secondary : Color.red)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                Spacer()

                                Button {
                                    Task { await testOllama() }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isTesting {
                                            ProgressView()
                                                .controlSize(.mini)
                                                .tint(.white)
                                        }
                                        Text(isTesting ? "Testing…" : "Test Connection")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(!ollamaHost.isEmpty ? Color(hex: "#8B5CF6") : Color.gray)
                                    .clipShape(Capsule())
                                }
                                .disabled(ollamaHost.isEmpty || isTesting)
                            }
                            .padding(14)
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                        // Setup instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Setting up Ollama", systemImage: "info.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: "#8B5CF6"))

                            Text("1. Install Ollama from **ollama.com**\n2. Run `ollama pull llama3.2:3b` in Terminal\n3. Enter your Mac's IP address above\n\nYour iPhone must be on the same WiFi network. Suggested small models: **llama3.2:3b** (2 GB), **qwen2.5:3b** (2 GB)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(Color(hex: "#8B5CF6").opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                    }

                    // Foundation Models info
                    if provider == .foundation {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("On-device AI requirements", systemImage: "info.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: "#06B6D4"))

                            Text("Requires:\n• iPhone 15 Pro, iPhone 15 Pro Max, or iPhone 16 series\n• iOS 18.2 or later\n• Apple Intelligence enabled in Settings > Apple Intelligence & Siri\n\nAll processing happens on-device. No network required.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if #unavailable(iOS 18.2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text("This device is running iOS \(UIDevice.current.systemVersion), which does not support on-device Foundation Models.")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(hex: "#06B6D4").opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                    }

                    Spacer().frame(height: 90)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("AI Analysis")
        .animation(.easeInOut(duration: 0.25), value: providerRaw)
        .animation(.easeInOut(duration: 0.2), value: testResult?.message)
    }

    // MARK: - Helpers

    private func iconView(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: 32, height: 32)
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func providerRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            HStack(spacing: 12) {
                iconView(icon, color: color)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(color)
                        .font(.title3)
                } else {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func testOllama() async {
        isTesting = true
        testResult = nil
        let service = OllamaLLMService()
        do {
            let msg = try await service.testConnection()
            await MainActor.run {
                testResult = TestResult(success: true, message: msg)
                isTesting = false
                Haptics.success()
            }
        } catch {
            await MainActor.run {
                testResult = TestResult(success: false, message: error.localizedDescription)
                isTesting = false
            }
        }
    }
}
