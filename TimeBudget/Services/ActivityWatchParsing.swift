import Foundation

// MARK: - Parsing Extensions

extension ActivityWatchService {

    /// System apps that represent the Mac being locked/asleep — not real desk time.
    static let systemIgnoreList: Set<String> = [
        "loginwindow", "WindowServer", "ScreenSaverEngine",
        "MacUserGenerator", "UserNotificationCenter", "Spotlight", "SecurityAgent",
    ]

    /// Common iOS bundle ID → display name mapping
    static let iosAppNames: [String: String] = [
        "com.apple.MobileSafari": "Safari",
        "com.apple.mobilenotes": "Notes",
        "com.apple.mobilemail": "Mail",
        "com.apple.mobilecal": "Calendar",
        "com.apple.reminders": "Reminders",
        "com.apple.mobileslideshow": "Photos",
        "com.apple.weather": "Weather",
        "com.apple.Maps": "Maps",
        "com.apple.Health": "Health",
        "com.apple.Music": "Music",
        "com.apple.Podcasts": "Podcasts",
        "com.apple.news": "News",
        "com.apple.AppStore": "App Store",
        "com.apple.iBooks": "Books",
        "com.apple.mobiletimer": "Clock",
        "com.apple.calculator": "Calculator",
        "com.apple.camera": "Camera",
        "com.apple.facetime": "FaceTime",
        "com.apple.MobileStore": "Apple Store",
        "com.apple.Preferences": "Settings",
        "com.burbn.instagram": "Instagram",
        "com.google.chrome.ios": "Chrome",
        "com.atebits.Tweetie2": "Twitter",
        "com.zhiliaoapp.musically": "TikTok",
        "com.facebook.Facebook": "Facebook",
        "com.toyopagroup.picaboo": "Snapchat",
        "com.google.ios.youtube": "YouTube",
        "net.whatsapp.WhatsApp": "WhatsApp",
        "com.spotify.client": "Spotify",
        "org.telegram.Telegram": "Telegram",
        "com.reddit.Reddit": "Reddit",
        "com.linkedin.LinkedIn": "LinkedIn",
        "com.discord.Discord": "Discord",
        "com.netflix.Netflix": "Netflix",
        "com.amazon.Amazon": "Amazon",
        "com.google.Gmail": "Gmail",
        "com.google.Maps": "Google Maps",
        "com.slack.Slack": "Slack",
        "com.microsoft.teams": "Teams",
        "us.zoom.videomeetings": "Zoom",
    ]

    /// iOS system noise prefixes — lock screen, springboard, etc.
    static let iosSystemPrefixes: [String] = [
        "com.apple.springboard", "com.apple.SleepLockScreen",
        "com.apple.ScreenshotServicesService", "com.apple.ClockAngel",
        "com.apple.CarPlayTemplateUIHost", "com.apple.Spotlight",
        "com.apple.InCallService", "com.apple.TelephonyUtilities",
    ]

    /// Resolve an iOS bundle ID or app name to a clean display name.
    static func resolveAppName(_ raw: String) -> String {
        if let mapped = iosAppNames[raw] { return mapped }
        if raw.contains(".") {
            return raw.components(separatedBy: ".").last?.capitalized ?? raw
        }
        return raw
    }

    // MARK: - Window Event Parsing

    func parseWindowEvents(_ data: Data) throws -> [AWEvent] {
        guard let events = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ActivityWatchError.invalidResponse
        }

        let formatter = Self.iso8601Formatter
        let fallback = Self.iso8601FallbackFormatter

        return events.compactMap { event -> AWEvent? in
            guard let id = event["id"] as? Int,
                  let timestampStr = event["timestamp"] as? String,
                  let duration = event["duration"] as? Double,
                  let eventData = event["data"] as? [String: Any] else { return nil }

            guard let timestamp = formatter.date(from: timestampStr)
                    ?? fallback.date(from: timestampStr) else { return nil }

            let app = (eventData["app"] as? String) ?? "Unknown"
            if Self.systemIgnoreList.contains(app) { return nil }

            let title = (eventData["title"] as? String) ?? ""

            return AWEvent(
                id: "\(id)",
                timestamp: timestamp,
                duration: duration,
                appName: app,
                windowTitle: title,
                url: nil,
                sourceDevice: .mac
            )
        }
        .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Chrome Web Event Parsing

    func parseWebEvents(_ data: Data) throws -> [AWEvent] {
        guard let events = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        let formatter = Self.iso8601Formatter
        let fallback = Self.iso8601FallbackFormatter

        return events.compactMap { event -> AWEvent? in
            guard let id = event["id"] as? Int,
                  let timestampStr = event["timestamp"] as? String,
                  let duration = event["duration"] as? Double,
                  let eventData = event["data"] as? [String: Any] else { return nil }

            guard let timestamp = formatter.date(from: timestampStr)
                    ?? fallback.date(from: timestampStr) else { return nil }

            let title = (eventData["title"] as? String) ?? ""
            let url = eventData["url"] as? String

            return AWEvent(
                id: "web-\(id)",
                timestamp: timestamp,
                duration: duration,
                appName: "Google Chrome",
                windowTitle: title,
                url: url,
                sourceDevice: .mac
            )
        }
        .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Screen Time Event Parsing

    func parseScreenTimeEvents(_ data: Data) throws -> [AWEvent] {
        guard let events = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        let formatter = Self.iso8601Formatter
        let fallback = Self.iso8601FallbackFormatter

        return events.compactMap { event -> AWEvent? in
            guard let id = event["id"] as? Int,
                  let timestampStr = event["timestamp"] as? String,
                  let duration = event["duration"] as? Double,
                  let eventData = event["data"] as? [String: Any] else { return nil }

            guard let timestamp = formatter.date(from: timestampStr)
                    ?? fallback.date(from: timestampStr) else { return nil }

            let rawApp = (eventData["app"] as? String) ?? "Unknown"
            if Self.iosSystemPrefixes.contains(where: { rawApp.hasPrefix($0) }) { return nil }

            let app = Self.resolveAppName(rawApp)
            let title = (eventData["title"] as? String) ?? ""

            return AWEvent(
                id: "st-\(id)",
                timestamp: timestamp,
                duration: duration,
                appName: app,
                windowTitle: title,
                url: nil,
                sourceDevice: .iphone
            )
        }
        .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Shared Formatters

    static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
