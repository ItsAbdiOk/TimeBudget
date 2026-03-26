import Foundation

// MARK: - Connection & Bucket Discovery

extension ActivityWatchService {

    func testConnection() async throws -> Bool {
        guard !desktopIP.isEmpty else { throw ActivityWatchError.notConfigured }

        let url = URL(string: "http://\(desktopIP):\(port)/api/0/info")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityWatchError.invalidResponse
        }
        return (200...299).contains(httpResponse.statusCode)
    }

    @discardableResult
    func discoverHostname() async throws -> String {
        guard !desktopIP.isEmpty else { throw ActivityWatchError.notConfigured }

        let url = URL(string: "http://\(desktopIP):\(port)/api/0/buckets")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ActivityWatchError.invalidResponse
        }

        guard let buckets = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ActivityWatchError.invalidResponse
        }

        var discovered = DiscoveredBuckets()
        for key in buckets.keys {
            if key.hasPrefix("aw-watcher-window_") {
                discovered.windowBucket = key
                discovered.hostname = String(key.dropFirst("aw-watcher-window_".count))
            } else if key.hasPrefix("aw-watcher-web-chrome") {
                discovered.webChromeBuckets.append(key)
            } else if key.hasPrefix("aw-import-screentime") {
                discovered.screenTimeBuckets.append(key)
                print("[ActivityWatch] Found screen time bucket: \(key)")
            }
        }

        guard let windowBucket = discovered.windowBucket,
              let discoveredHostname = discovered.hostname else {
            throw ActivityWatchError.noBucket
        }

        self.discoveredBuckets = discovered
        UserDefaults.standard.set(discoveredHostname, forKey: "activitywatch_hostname")
        print("[ActivityWatch] Discovered — window: \(windowBucket), chrome: \(discovered.webChromeBuckets), screenTime: \(discovered.screenTimeBuckets)")
        return discoveredHostname
    }
}
