import Foundation

// MARK: - Fetching & Enrichment Extensions

extension ActivityWatchService {

    // MARK: - Window Events

    func fetchWindowEvents(from start: Date, to end: Date) async throws -> [AWEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let urlStr = "http://\(desktopIP):\(port)/api/0/buckets/\(bucketId)/events?start=\(formatter.string(from: start))&end=\(formatter.string(from: end))&limit=-1"

        guard let url = URL(string: urlStr) else {
            throw ActivityWatchError.notConfigured
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ActivityWatchError.unreachable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityWatchError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw ActivityWatchError.noBucket
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ActivityWatchError.invalidResponse
        }

        return try parseWindowEvents(data)
    }

    // MARK: - Chrome Web Events

    func fetchWebEventsInRange(from start: Date, to end: Date) async throws -> [AWEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let bucketNames = ["aw-watcher-web-chrome", "aw-watcher-web-chrome_\(hostname)"]

        for bucketName in bucketNames {
            let urlStr = "http://\(desktopIP):\(port)/api/0/buckets/\(bucketName)/events?start=\(formatter.string(from: start))&end=\(formatter.string(from: end))&limit=-1"
            guard let url = URL(string: urlStr) else { continue }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 5

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else { continue }
                let events = try parseWebEvents(data)
                if !events.isEmpty {
                    print("[ActivityWatch] Fetched \(events.count) Chrome web events from \(bucketName)")
                    return events
                }
            } catch {
                print("[ActivityWatch] Failed to fetch \(bucketName): \(error.localizedDescription)")
                continue
            }
        }

        return []
    }

    // MARK: - Screen Time Events

    func fetchScreenTimeEvents(from start: Date, to end: Date) async -> [AWEvent] {
        guard let buckets = discoveredBuckets?.screenTimeBuckets, !buckets.isEmpty else { return [] }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var allEvents: [AWEvent] = []

        for bucket in buckets {
            let urlStr = "http://\(desktopIP):\(port)/api/0/buckets/\(bucket)/events?start=\(formatter.string(from: start))&end=\(formatter.string(from: end))&limit=-1"
            guard let url = URL(string: urlStr) else { continue }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else { continue }
                let events = try parseScreenTimeEvents(data)
                if !events.isEmpty {
                    print("[ActivityWatch] Fetched \(events.count) screen time events from \(bucket)")
                    allEvents.append(contentsOf: events)
                }
            } catch {
                print("[ActivityWatch] Failed to fetch screen time from \(bucket): \(error.localizedDescription)")
            }
        }

        return allEvents.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Web Enrichment

    /// Enrich Mac browser window events with Chrome extension URLs,
    /// and merge unmatched web events as standalone entries.
    func enrichWithWebEvents(_ windowEvents: [AWEvent], from start: Date, to end: Date) async -> [AWEvent] {
        guard let webEvents = try? await fetchWebEventsInRange(from: start, to: end),
              !webEvents.isEmpty else {
            return windowEvents
        }

        print("[ActivityWatch] Enriching \(windowEvents.count) window events with \(webEvents.count) web events")

        var enriched = windowEvents
        var enrichedCount = 0
        var matchedWebIndices = Set<Int>()
        let browsers: Set<String> = ["Google Chrome", "Brave Browser", "Microsoft Edge", "Arc"]

        // Pass 1: Enrich Mac browser window events with matching web URLs
        for i in enriched.indices {
            guard enriched[i].url == nil,
                  enriched[i].sourceDevice != .iphone,
                  browsers.contains(enriched[i].appName) else { continue }

            let evtStart = enriched[i].timestamp
            let evtEnd = evtStart.addingTimeInterval(enriched[i].duration)

            for (wi, web) in webEvents.enumerated() {
                let webStart = web.timestamp
                let webEnd = webStart.addingTimeInterval(web.duration)
                let overlapStart = max(evtStart, webStart)
                let overlapEnd = min(evtEnd, webEnd)
                if overlapEnd.timeIntervalSince(overlapStart) >= 1 {
                    enriched[i].url = web.url
                    enrichedCount += 1
                    matchedWebIndices.insert(wi)
                    break
                }
            }
        }

        // Pass 2: Add unmatched web events as standalone entries (>= 30s)
        var addedCount = 0
        for (wi, web) in webEvents.enumerated() {
            guard !matchedWebIndices.contains(wi), web.duration >= 30 else { continue }
            enriched.append(web)
            addedCount += 1
        }

        let browserCount = windowEvents.filter { browsers.contains($0.appName) }.count
        print("[ActivityWatch] Enriched \(enrichedCount)/\(browserCount) browser events with URLs, added \(addedCount) standalone web events")
        return enriched
    }
}
