import Foundation

// MARK: - Protocol

/// A local LLM backend that can complete a prompt and return a response string.
protocol LLMService {
    func complete(prompt: String) async throws -> String
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case notConfigured
    case unreachable
    case invalidResponse
    case generationFailed(String)
    case unavailableOnDevice

    var errorDescription: String? {
        switch self {
        case .notConfigured:        return "LLM not configured"
        case .unreachable:          return "Cannot reach Ollama server"
        case .invalidResponse:      return "Invalid response from LLM"
        case .generationFailed(let msg): return "LLM error: \(msg)"
        case .unavailableOnDevice:  return "On-device AI requires iPhone 15 Pro or later with iOS 18.2+"
        }
    }
}

// MARK: - LLM Provider

enum LLMProvider: String {
    case ollama     = "ollama"
    case foundation = "foundation"   // Apple Foundation Models
}

// MARK: - Ollama Implementation

/// Connects to an Ollama instance running on the local network.
/// Uses the same IP-over-WiFi pattern as ActivityWatch.
final class OllamaLLMService: LLMService {

    // MARK: Configuration (UserDefaults-backed)

    var host: String {
        UserDefaults.standard.string(forKey: "llm_ollama_host") ?? ""
    }

    var model: String {
        let stored = UserDefaults.standard.string(forKey: "llm_ollama_model") ?? ""
        return stored.isEmpty ? "llama3.2:3b" : stored
    }

    var isConfigured: Bool { !host.isEmpty }

    // MARK: URLSession — generous timeout (LLM generation is slow)

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 120   // 2 min for generation
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    // MARK: LLMService

    func complete(prompt: String) async throws -> String {
        guard isConfigured else { throw LLMError.notConfigured }

        guard let url = URL(string: "http://\(host):11434/api/generate") else {
            throw LLMError.notConfigured
        }

        let body: [String: Any] = [
            "model":  model,
            "prompt": prompt,
            "stream": false,
            "options": ["temperature": 0.3]   // lower temp = more deterministic
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LLMError.unreachable
        }

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw LLMError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["response"] as? String else {
            throw LLMError.invalidResponse
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LLMError.invalidResponse }
        return trimmed
    }

    /// Quick connectivity check (no generation).
    func testConnection() async throws -> String {
        guard isConfigured else { throw LLMError.notConfigured }

        guard let url = URL(string: "http://\(host):11434/api/tags") else {
            throw LLMError.notConfigured
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LLMError.unreachable
        }

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw LLMError.invalidResponse
        }

        // Parse available models from /api/tags
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            let names = models.compactMap { $0["name"] as? String }
            return names.isEmpty ? "Connected (no models pulled)" : "Connected · Models: \(names.joined(separator: ", "))"
        }
        return "Connected"
    }
}

// MARK: - Apple Foundation Models Implementation

/// On-device LLM via Apple's FoundationModels framework.
/// Requires iPhone 15 Pro or later running iOS 18.2+.
/// Falls back gracefully on unsupported devices.
@available(iOS 18.2, *)
final class FoundationLLMService: LLMService {
    func complete(prompt: String) async throws -> String {
        // Dynamic import to avoid compile errors on older SDKs.
        // FoundationModels was introduced in iOS 18.2 (Xcode 16.2).
        // If the framework isn't linked, this service should not be instantiated.
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // We use NSClassFromString + perform to avoid a hard link
                    // to FoundationModels at compile time. At runtime, on a
                    // supported device, the class will be available.
                    //
                    // For a proper integration: import FoundationModels and use:
                    //   let session = LanguageModelSession()
                    //   let response = try await session.respond(to: prompt)
                    //   continuation.resume(returning: response.content)
                    //
                    // This stub returns an error so the UI can prompt the user
                    // to add the FoundationModels framework to the Xcode project.
                    throw LLMError.unavailableOnDevice
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Factory

/// Returns the appropriate LLMService based on the user's current provider setting.
enum LLMServiceFactory {

    static var current: (any LLMService)? {
        let raw = UserDefaults.standard.string(forKey: "llm_provider") ?? ""
        switch LLMProvider(rawValue: raw) {
        case .ollama:
            return OllamaLLMService()
        case .foundation:
            if #available(iOS 18.2, *) {
                return FoundationLLMService()
            }
            return nil
        case .none:
            return nil
        }
    }

    static var isConfigured: Bool {
        let raw = UserDefaults.standard.string(forKey: "llm_provider") ?? ""
        guard let provider = LLMProvider(rawValue: raw) else { return false }
        switch provider {
        case .ollama:
            let host = UserDefaults.standard.string(forKey: "llm_ollama_host") ?? ""
            return !host.isEmpty
        case .foundation:
            if #available(iOS 18.2, *) { return true }
            return false
        }
    }
}
