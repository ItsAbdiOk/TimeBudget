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
        // Apple apps
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
        "com.apple.mobilephone": "Phone",
        "com.apple.MobileSMS": "Messages",
        "com.apple.tips": "Tips",
        "com.apple.Fitness": "Fitness",
        "com.apple.shortcuts": "Shortcuts",
        "com.apple.VoiceMemos": "Voice Memos",
        "com.apple.Translate": "Translate",
        "com.apple.compass": "Compass",
        "com.apple.measure": "Measure",
        "com.apple.DocumentsApp": "Files",
        "com.apple.Home": "Home",
        "com.apple.findmy": "Find My",
        "com.apple.clips": "Clips",
        "com.apple.iMovie": "iMovie",
        "com.apple.garageband": "GarageBand",
        "com.apple.Keynote": "Keynote",
        "com.apple.Pages": "Pages",
        "com.apple.Numbers": "Numbers",
        "com.apple.TestFlight": "TestFlight",
        // Social & messaging
        "com.burbn.instagram": "Instagram",
        "com.zhiliaoapp.musically": "TikTok",
        "com.facebook.Facebook": "Facebook",
        "com.toyopagroup.picaboo": "Snapchat",
        "net.whatsapp.WhatsApp": "WhatsApp",
        "org.telegram.Telegram": "Telegram",
        "com.discord.Discord": "Discord",
        "com.reddit.Reddit": "Reddit",
        "com.linkedin.LinkedIn": "LinkedIn",
        "com.atebits.Tweetie2": "Twitter",
        "com.twitter.twitter": "Twitter",
        "com.facebook.Messenger": "Messenger",
        "com.viber.app": "Viber",
        "jp.naver.line": "LINE",
        "com.pinterest": "Pinterest",
        "com.tumblr.tumblr": "Tumblr",
        // Google
        "com.google.chrome.ios": "Chrome",
        "com.google.ios.youtube": "YouTube",
        "com.google.Gmail": "Gmail",
        "com.google.Maps": "Google Maps",
        "com.google.Drive": "Google Drive",
        "com.google.photos": "Google Photos",
        "com.google.Docs": "Google Docs",
        "com.google.Sheets": "Google Sheets",
        "com.google.Slides": "Google Slides",
        "com.google.Authenticator": "Google Auth",
        "com.google.Meet": "Google Meet",
        // Productivity & work
        "com.slack.Slack": "Slack",
        "com.microsoft.teams": "Teams",
        "us.zoom.videomeetings": "Zoom",
        "com.microsoft.Office.Outlook": "Outlook",
        "com.microsoft.Office.Word": "Word",
        "com.microsoft.Office.Excel": "Excel",
        "com.microsoft.Office.Powerpoint": "PowerPoint",
        "com.microsoft.onenote": "OneNote",
        "com.notion.id": "Notion",
        "com.getdropbox.Dropbox": "Dropbox",
        "com.trello.Trello": "Trello",
        "com.figma.FigmaMirror": "Figma",
        // Entertainment & media
        "com.spotify.client": "Spotify",
        "com.netflix.Netflix": "Netflix",
        "com.amazon.Amazon": "Amazon",
        "com.amazon.aiv": "Prime Video",
        "com.disneyplus": "Disney+",
        "tv.twitch": "Twitch",
        "com.soundcloud.TouchApp": "SoundCloud",
        "com.audible.iphone": "Audible",
        "com.shiftjis.pocketcasts": "Pocket Casts",
        "au.com.shiftyjelly.pocketcasts": "Pocket Casts",
        // Manga & reading
        "com.oolaa.tachimanga": "Tachimanga",
        "com.oolaa.Tachimanga": "Tachimanga",
        "moe.ktt.tachiyomi": "Tachimanga",
        "com.mangastorm": "Manga Storm",
        "com.crunchyroll.iphone": "Crunchyroll",
        // Finance & banking
        "com.saltedge.connect": "saltedge.com",
        "com.apple.Wallet": "Wallet",
        "com.paypal.PPClient": "PayPal",
        "com.revolut.revolut": "Revolut",
        "com.monzo.monzo": "Monzo",
        // Dev & tools
        "com.anthropic.claudeApp": "Claude",
        "com.anthropic.claude": "Claude",
        "com.openai.chat": "ChatGPT",
        "com.github.stormbreaker.prod": "GitHub",
        "com.riley.altstore": "AltStore",
        "com.riley.AltStore": "AltStore",
        // Utility
        "com.1password.ios": "1Password",
        "com.noodlesoft.Pastebot-iOS": "Pastebot",
        "com.culturedcode.ThingsiPhone": "Things",
        "com.hammerandchisel.discord": "Discord",
    ]

    /// iOS system noise — exact bundle IDs and prefixes for non-user-facing processes.
    /// Keep this tight: only filter things that are genuinely not user activity.
    static let iosSystemPrefixes: [String] = [
        "com.apple.springboard",
        "com.apple.SleepLockScreen",
        "com.apple.ScreenshotServicesService",
        "com.apple.CarPlayTemplateUIHost",
        "com.apple.TelephonyUtilities",
        "com.apple.InCallService",
        "com.apple.BackgroundTaskAgent",
        "com.apple.dt.Xcode", // Xcode companion on phone
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
