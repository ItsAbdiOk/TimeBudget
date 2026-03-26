import Foundation

extension DeskTimeViewModel {

    // MARK: - Data Loading

    @MainActor
    func loadData() async {
        isLoading = true
        let calendar = Calendar.current
        let now = Date()
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now)!

        var fetched = (try? await service.fetchBlocks(from: ninetyDaysAgo, to: now)) ?? []

        guard !fetched.isEmpty else {
            isLoading = false
            return
        }

        // Apply AI categorization to today's blocks
        if #available(iOS 26, *) {
            let enabled = UserDefaults.standard.bool(forKey: "intelligence_categorization_enabled")
            if enabled {
                let todayStart = calendar.startOfDay(for: now)
                let todayBlocksForAI = fetched.filter { $0.start >= todayStart }
                if !todayBlocksForAI.isEmpty {
                    await applyAICategorization(to: &fetched, todayBlocks: todayBlocksForAI)
                }
            }
        }

        blocks = fetched
        aiRefinedCount = fetched.filter { calendar.isDateInToday($0.start) && $0.isAIRefined }.count

        let todayEvents = (try? await service.fetchRawEvents(for: now)) ?? []
        allEvents = todayEvents
        productivityScore = ProductivityClassifier.productivityScore(events: todayEvents)

        // Aggregate
        var daily: [Date: Int] = [:]
        var appDeviceDurations: [String: (duration: TimeInterval, device: AWSourceDevice)] = [:]
        var siteDurations: [String: TimeInterval] = [:]
        var totalMins = 0
        var maxSessionMins = 0
        var tierMins: [ProductivityTier: Int] = [:]
        var seenIPhone = false

        for block in fetched {
            let day = calendar.startOfDay(for: block.start)
            let mins = block.durationMinutes
            daily[day, default: 0] += mins
            totalMins += mins
            maxSessionMins = max(maxSessionMins, mins)

            for event in block.events {
                let device = event.sourceDevice
                if device == .iphone { seenIPhone = true }
                let key = "\(event.appName)|\(device.rawValue)"
                let existing = appDeviceDurations[key]
                appDeviceDurations[key] = (
                    duration: (existing?.duration ?? 0) + event.duration,
                    device: device
                )
                if let site = event.siteName {
                    siteDurations[site, default: 0] += event.duration
                }
            }
        }

        hasIPhoneData = seenIPhone

        var macMins = 0
        var iphoneMins = 0
        for block in fetched {
            if block.dominantDevice == .iphone {
                iphoneMins += block.durationMinutes
            } else {
                macMins += block.durationMinutes
            }
        }
        macMinutes = macMins
        iphoneMinutes = iphoneMins

        let todayBlocksForTier = fetched.filter { calendar.isDateInToday($0.start) }
        if !todayBlocksForTier.isEmpty {
            for block in todayBlocksForTier {
                let tier = ProductivityTier(rawValue: block.effectiveCategory) ?? .neutral
                tierMins[tier, default: 0] += block.durationMinutes
            }
        } else {
            for event in todayEvents {
                let tier = ProductivityClassifier.classify(app: event.appName, site: event.siteName)
                tierMins[tier, default: 0] += event.durationMinutes
            }
        }

        totalMinutes = totalMins
        longestSession = maxSessionMins
        dailyData = daily
        let activeDays = daily.count
        avgPerDay = activeDays > 0 ? totalMins / activeDays : 0

        tierBreakdown = tierMins
            .map { (tier: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }

        appStats = appDeviceDurations.map { key, value in
            let appName = String(key.split(separator: "|").first ?? "")
            let mins = Int(value.duration / 60)
            let tier = ProductivityClassifier.classify(app: appName, site: nil)
            return (app: appName, minutes: mins, tier: tier, device: value.device)
        }
        .sorted { $0.minutes > $1.minutes }

        siteStats = siteDurations.map { site, duration in
            let mins = Int(duration / 60)
            let tier = ProductivityClassifier.classify(app: "Google Chrome", site: site)
            return (site: site, minutes: mins, tier: tier)
        }
        .sorted { $0.minutes > $1.minutes }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        var weekBuckets: [(label: String, minutes: Int)] = []
        for i in (0..<12).reversed() {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: calendar.startOfDay(for: now))!
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
            var weekMins = 0
            for (day, mins) in daily {
                if day >= weekStart && day < weekEnd { weekMins += mins }
            }
            weekBuckets.append((label: formatter.string(from: weekStart), minutes: weekMins))
        }
        weeklyData = weekBuckets.map { (week: $0.label, minutes: $0.minutes) }

        isLoading = false
    }

    // MARK: - AI Categorization

    @available(iOS 26, *)
    func applyAICategorization(to blocks: inout [AWActivityBlock], todayBlocks: [AWActivityBlock]) async {
        let intelligence = IntelligenceService.shared
        if await !intelligence.isReady {
            print("[DeskTime] Intelligence not ready, warming up...")
            await intelligence.warmUp()
        }
        guard await intelligence.isReady else {
            print("[DeskTime] Intelligence unavailable on this device")
            return
        }

        let validCategories = ["Deep Work", "Work", "Meetings", "Reading", "Podcast", "Exercise",
                               "Walking", "Running", "Cycling", "Commute", "Sleep", "Fajr",
                               "Desk Time", "Other", "Productive", "Neutral", "Distraction"]

        var idToIndex: [String: Int] = [:]
        for i in blocks.indices { idToIndex[blocks[i].id.uuidString] = i }

        let items = todayBlocks.prefix(50).map { block in
            let urls = block.events.compactMap { $0.url }.prefix(3)
            let urlString = urls.isEmpty ? nil : urls.joined(separator: ", ")
            return UncategorizedItem(
                id: block.id.uuidString,
                app: block.topApp,
                title: block.events.first?.windowTitle ?? "",
                site: urlString ?? block.topSite,
                durationMinutes: block.durationMinutes
            )
        }

        print("[DeskTime] Sending \(items.count) blocks to AI for categorization")
        for item in items.prefix(3) {
            print("[DeskTime]   - \(item.app) | \(item.site ?? "no site") | \(item.title.prefix(40))")
        }

        do {
            let results = try await intelligence.categorize(items: items, validCategories: validCategories)
            var applied = 0
            for item in results {
                if let idx = idToIndex[item.id] {
                    blocks[idx].aiCategory = item.category
                    applied += 1
                }
            }
            print("[DeskTime] AI categorized \(results.count) items, applied \(applied) to blocks")
            for item in results.prefix(5) {
                let original = todayBlocks.first(where: { $0.id.uuidString == item.id })?.category ?? "?"
                print("[DeskTime]   \(original) -> \(item.category) (conf: \(String(format: "%.0f%%", item.confidence * 100)))")
            }
        } catch {
            print("[DeskTime] AI categorization failed: \(error.localizedDescription)")
        }
    }
}
