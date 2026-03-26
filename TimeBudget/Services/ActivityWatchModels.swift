import Foundation

// MARK: - Device Source

enum AWSourceDevice: String, Codable {
    case mac
    case iphone
    case unknown
}

// MARK: - Event

struct AWEvent: Identifiable {
    let id: String
    let timestamp: Date
    let duration: TimeInterval      // seconds
    let appName: String
    let windowTitle: String
    var url: String?                 // from aw-watcher-web-chrome
    var sourceDevice: AWSourceDevice = .unknown

    var durationMinutes: Int { Int(duration / 60) }

    /// Extract the domain from a full URL (e.g., "https://github.com/foo" → "github.com")
    var urlDomain: String? {
        guard let url, let components = URLComponents(string: url) else { return nil }
        return components.host?.replacingOccurrences(of: "www.", with: "")
    }

    /// Site name: real URL domain preferred, then known-site matching from window titles.
    var siteName: String? {
        if let domain = urlDomain { return domain }

        let browsers: Set<String> = [
            "Google Chrome", "Safari", "Firefox", "Arc",
            "Brave Browser", "Microsoft Edge", "Orion",
        ]
        guard browsers.contains(appName) else { return nil }

        let titleLower = windowTitle.lowercased()

        for site in Self.knownSites {
            for keyword in site.keywords {
                if titleLower.contains(keyword) { return site.domain }
            }
        }
        return nil
    }

    // MARK: - Known Sites Map

    private static let knownSites: [(keywords: [String], domain: String)] = [
        // Dev / Deep Work
        (["github.com", "github"], "github.com"),
        (["gitlab"], "gitlab.com"),
        (["stack overflow", "stackoverflow"], "stackoverflow.com"),
        (["claude.ai", "claude"], "claude.ai"),
        (["chatgpt"], "chatgpt.com"),
        (["perplexity"], "perplexity.ai"),
        (["notion.so", "notion"], "notion.so"),
        (["linear"], "linear.app"),
        (["figma"], "figma.com"),
        (["vercel"], "vercel.com"),
        (["netlify"], "netlify.com"),
        (["localhost", "127.0.0.1"], "localhost"),
        (["developer.apple"], "developer.apple.com"),
        (["swift.org"], "swift.org"),
        // Docs / Productive
        (["docs.google"], "docs.google.com"),
        (["sheets.google"], "sheets.google.com"),
        (["slides.google"], "slides.google.com"),
        (["drive.google"], "drive.google.com"),
        (["wikipedia"], "wikipedia.org"),
        (["medium.com"], "medium.com"),
        (["coursera"], "coursera.org"),
        (["udemy"], "udemy.com"),
        // Distraction
        (["youtube.com", "youtube"], "youtube.com"),
        (["twitter.com", "x.com"], "x.com"),
        (["reddit.com", "reddit"], "reddit.com"),
        (["instagram"], "instagram.com"),
        (["facebook"], "facebook.com"),
        (["tiktok"], "tiktok.com"),
        (["netflix"], "netflix.com"),
        (["twitch.tv", "twitch"], "twitch.tv"),
        (["discord.com"], "discord.com"),
        (["amazon"], "amazon.com"),
        // Communication
        (["gmail"], "gmail.com"),
        (["outlook"], "outlook.com"),
        (["slack"], "slack.com"),
        (["zoom"], "zoom.us"),
        (["meet.google"], "meet.google.com"),
        (["teams.microsoft"], "teams.microsoft.com"),
    ]
}

// MARK: - Activity Block

/// A bundled block of consecutive desktop activity
struct AWActivityBlock: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let category: String            // "Deep Work", "Productive", "Neutral", "Distraction"
    let topApp: String              // most-used app in this block
    let topSite: String?            // most-used website (if browser-heavy)
    let events: [AWEvent]
    var aiCategory: String?         // set by Apple Intelligence

    var effectiveCategory: String { aiCategory ?? category }
    var isAIRefined: Bool { aiCategory != nil && aiCategory != category }
    var durationMinutes: Int { Int(end.timeIntervalSince(start) / 60) }

    var dominantDevice: AWSourceDevice {
        var counts: [AWSourceDevice: TimeInterval] = [:]
        for event in events {
            counts[event.sourceDevice, default: 0] += event.duration
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? .mac
    }
}

// MARK: - Errors

enum ActivityWatchError: LocalizedError {
    case notConfigured
    case unreachable
    case invalidResponse
    case noBucket
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Desktop IP not configured"
        case .unreachable: return "ActivityWatch server unreachable"
        case .invalidResponse: return "Invalid response from ActivityWatch"
        case .noBucket: return "No window watcher bucket found"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}
