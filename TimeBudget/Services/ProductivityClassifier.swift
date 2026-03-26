import Foundation

// MARK: - Productivity Tier

enum ProductivityTier: String {
    case productive = "Productive"
    case deepWork = "Deep Work"
    case neutral = "Neutral"
    case distraction = "Distraction"

    var color: String {
        switch self {
        case .deepWork: return "systemGreen"
        case .productive: return "systemTeal"
        case .neutral: return "systemOrange"
        case .distraction: return "systemRed"
        }
    }
}

// MARK: - Classifier

struct ProductivityClassifier {

    static let deepWorkApps: Set<String> = [
        "Xcode", "Visual Studio Code", "Code", "Terminal", "iTerm2",
        "IntelliJ IDEA", "PyCharm", "WebStorm", "Sublime Text", "Vim",
        "Neovim", "Cursor", "Android Studio", "CLion", "DataGrip",
        "Ghostty", "Warp", "Alacritty", "Kitty",
        "Claude",
    ]

    static let productiveApps: Set<String> = [
        "Notion", "Obsidian", "Notes", "Pages", "Numbers", "Keynote",
        "Microsoft Word", "Microsoft Excel", "Microsoft PowerPoint",
        "Figma", "Sketch", "Adobe Photoshop", "Adobe Illustrator",
        "Logic Pro", "Final Cut Pro", "DaVinci Resolve",
        "Simulator", "Instruments", "FileMerge",
        "Preview", "Finder", "Calendar", "Mail", "Reminders",
        "System Settings", "Activity Monitor",
        "Gmail", "Google Maps", "Slack", "Teams", "Zoom",
        "Photos", "Weather", "Maps", "Health", "Books",
        "Podcasts", "Music", "LinkedIn",
    ]

    static let distractionApps: Set<String> = [
        "Messages", "WhatsApp", "Telegram", "Discord",
        "Instagram", "TikTok", "Snapchat", "Facebook",
        "Netflix", "Twitch", "Reddit",
    ]

    static let productiveSites: Set<String> = [
        "github", "stackoverflow", "gitlab", "bitbucket",
        "claude", "chatgpt", "perplexity",
        "notion", "linear", "jira", "asana", "trello",
        "docs.google", "sheets.google", "slides.google",
        "figma", "miro", "confluence",
        "leetcode", "hackerrank", "codewars",
        "developer.mozilla", "developer.apple", "swift.org",
        "coursera", "udemy", "edx", "khanacademy",
        "scholar.google", "arxiv", "researchgate",
        "wikipedia", "wolfram",
        "localhost", "127.0.0.1", "192.168",
        "aws.amazon", "cloud.google", "azure", "vercel", "netlify",
        "hub.docker", "npmjs",
    ]

    static let neutralSites: Set<String> = [
        "youtube",  // AI decides based on video content
    ]

    static let distractionSites: Set<String> = [
        "twitter", "x.com", "reddit",
        "instagram", "facebook", "tiktok", "snapchat",
        "netflix", "twitch", "disneyplus", "hulu",
        "9gag", "imgur", "buzzfeed",
        "amazon", "ebay", "aliexpress",
    ]

    private static let browsers: Set<String> = [
        "Google Chrome", "Safari", "Firefox", "Arc",
        "Brave Browser", "Microsoft Edge", "Orion",
    ]

    static func classify(app: String, site: String?) -> ProductivityTier {
        if deepWorkApps.contains(app) { return .deepWork }
        if distractionApps.contains(app) { return .distraction }

        if browsers.contains(app), let site {
            let siteLower = site.lowercased()
            for productive in productiveSites {
                if siteLower.contains(productive.lowercased()) { return .productive }
            }
            // YouTube etc. default to neutral — AI refines based on content
            for neutral in neutralSites {
                if siteLower.contains(neutral.lowercased()) { return .neutral }
            }
            for distraction in distractionSites {
                if siteLower.contains(distraction.lowercased()) { return .distraction }
            }
            return .neutral
        }

        if productiveApps.contains(app) { return .productive }
        return .neutral
    }

    /// Score: 0-100 based on time distribution across tiers
    static func productivityScore(events: [AWEvent]) -> Int {
        guard !events.isEmpty else { return 0 }

        var tierDurations: [ProductivityTier: TimeInterval] = [:]
        for event in events {
            let tier = classify(app: event.appName, site: event.siteName)
            tierDurations[tier, default: 0] += event.duration
        }

        let total = tierDurations.values.reduce(0, +)
        guard total > 0 else { return 0 }

        let deepWork = (tierDurations[.deepWork] ?? 0) * 100
        let productive = (tierDurations[.productive] ?? 0) * 80
        let neutral = (tierDurations[.neutral] ?? 0) * 40

        return min(100, Int((deepWork + productive + neutral) / total))
    }
}
