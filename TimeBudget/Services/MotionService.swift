import Foundation
import CoreMotion

enum DetectedActivity: String, Codable {
    case stationary
    case walking
    case running
    case automotive
    case cycling
    case unknown
}

@Observable
final class MotionService {
    static let shared = MotionService()

    private let activityManager = CMMotionActivityManager()
    private(set) var currentActivity: DetectedActivity = .unknown
    private(set) var isAvailable = CMMotionActivityManager.isActivityAvailable()
    private(set) var isReceivingLiveUpdates = false

    // MARK: - Live Activity Updates (foreground only, for active Focus Sessions)

    /// Start real-time activity updates. Only call this when a Focus Session is running
    /// and the app is in the foreground. Stops automatically when the app backgrounds.
    func startLiveUpdates() {
        guard isAvailable, !isReceivingLiveUpdates else { return }
        isReceivingLiveUpdates = true

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }
            self?.currentActivity = Self.classify(activity)
        }
    }

    func stopLiveUpdates() {
        guard isReceivingLiveUpdates else { return }
        activityManager.stopActivityUpdates()
        isReceivingLiveUpdates = false
    }

    // MARK: - One-shot current activity (foreground snapshot, no persistent subscription)

    /// Query the most recent activity without keeping a live subscription open.
    /// Use this on dashboard appear to show "Right Now" status.
    func fetchCurrentActivity() async {
        guard isAvailable else { return }

        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-300)

        let activities = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CMMotionActivity], Error>) in
            activityManager.queryActivityStarting(from: fiveMinutesAgo, to: now, to: .main) { activities, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: activities ?? [])
                }
            }
        }

        if let latest = activities?.last {
            currentActivity = Self.classify(latest)
        }
    }

    // MARK: - Historical Batch Query (used by TimeClassifier)

    /// Fetch activity segments for a time range. This is a one-shot query that does NOT
    /// keep any sensor active — Core Motion stores ~7 days of history on-device.
    func fetchActivities(from start: Date, to end: Date) async throws -> [ActivitySegment] {
        guard isAvailable else { return [] }

        let activities = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CMMotionActivity], Error>) in
            activityManager.queryActivityStarting(from: start, to: end, to: .main) { activities, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: activities ?? [])
                }
            }
        }

        return Self.buildSegments(from: activities, end: end)
    }

    // MARK: - Classification

    private static func classify(_ activity: CMMotionActivity) -> DetectedActivity {
        if activity.cycling { return .cycling }
        if activity.running { return .running }
        if activity.automotive { return .automotive }
        if activity.walking { return .walking }
        if activity.stationary { return .stationary }
        return .unknown
    }

    private static func buildSegments(from activities: [CMMotionActivity], end: Date) -> [ActivitySegment] {
        guard !activities.isEmpty else { return [] }

        var segments: [ActivitySegment] = []
        let validActivities = activities.filter { $0.confidence != .low }

        for i in 0..<validActivities.count {
            let activity = validActivities[i]
            let type = classify(activity)
            guard type != .unknown else { continue }

            let startDate = activity.startDate
            let endDate: Date
            if i + 1 < validActivities.count {
                endDate = validActivities[i + 1].startDate
            } else {
                endDate = end
            }

            // Skip very short segments (< 2 minutes)
            guard endDate.timeIntervalSince(startDate) >= 120 else { continue }

            // Merge with previous segment if same type
            if let last = segments.last, last.activity == type {
                segments[segments.count - 1] = ActivitySegment(
                    startDate: last.startDate,
                    endDate: endDate,
                    activity: type,
                    confidence: max(last.confidence, Self.confidenceValue(activity.confidence))
                )
            } else {
                segments.append(ActivitySegment(
                    startDate: startDate,
                    endDate: endDate,
                    activity: type,
                    confidence: Self.confidenceValue(activity.confidence)
                ))
            }
        }

        return segments
    }

    private static func confidenceValue(_ confidence: CMMotionActivityConfidence) -> Double {
        switch confidence {
        case .high: return 0.9
        case .medium: return 0.7
        case .low: return 0.4
        @unknown default: return 0.5
        }
    }
}

struct ActivitySegment {
    let startDate: Date
    let endDate: Date
    let activity: DetectedActivity
    let confidence: Double

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
}
