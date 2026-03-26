import Foundation

enum DeskTimeMockData {
    static var sampleBlocks: [AWActivityBlock] {
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)

        let block1Start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: todayStart)!
        let block1End = cal.date(bySettingHour: 10, minute: 30, second: 0, of: todayStart)!
        let block2Start = cal.date(bySettingHour: 11, minute: 0, second: 0, of: todayStart)!
        let block2End = cal.date(bySettingHour: 12, minute: 0, second: 0, of: todayStart)!
        let block3Start = cal.date(bySettingHour: 13, minute: 0, second: 0, of: todayStart)!
        let block3End = cal.date(bySettingHour: 13, minute: 45, second: 0, of: todayStart)!

        let event1 = AWEvent(
            id: "e1", timestamp: block1Start, duration: 5400,
            appName: "Xcode", windowTitle: "TimeBudget - DeskTimeDetailView.swift",
            sourceDevice: .mac
        )
        let event2 = AWEvent(
            id: "e2", timestamp: block2Start, duration: 3600,
            appName: "Google Chrome", windowTitle: "github.com - Pull Request",
            url: "https://github.com/pulls", sourceDevice: .mac
        )
        let event3 = AWEvent(
            id: "e3", timestamp: block3Start, duration: 2700,
            appName: "Safari", windowTitle: "YouTube - Music",
            url: "https://youtube.com", sourceDevice: .iphone
        )

        return [
            AWActivityBlock(start: block1Start, end: block1End, category: "Deep Work",
                            topApp: "Xcode", topSite: nil, events: [event1]),
            AWActivityBlock(start: block2Start, end: block2End, category: "Productive",
                            topApp: "Google Chrome", topSite: "github.com", events: [event2]),
            AWActivityBlock(start: block3Start, end: block3End, category: "Distraction",
                            topApp: "Safari", topSite: "youtube.com", events: [event3])
        ]
    }
}
