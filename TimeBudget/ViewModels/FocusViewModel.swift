import Foundation
import SwiftData
import SwiftUI

@Observable
final class FocusViewModel {
    var activeSession: FocusSession?
    var selectedCategory: String = "Coding"
    var elapsedTime: TimeInterval = 0
    var recentSessions: [FocusSession] = []

    private var timer: Timer?

    var isRunning: Bool {
        activeSession?.isRunning ?? false
    }

    var elapsedFormatted: String {
        let total = Int(elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start(context: ModelContext) {
        let session = FocusSession(categoryName: selectedCategory)
        context.insert(session)
        activeSession = session
        elapsedTime = 0
        startTimer()

        // Start live motion updates while focus session is active
        MotionService.shared.startLiveUpdates()
    }

    func stop(context: ModelContext) {
        guard let session = activeSession else { return }
        session.stop()
        stopTimer()

        // Stop live motion updates — no active session needs them
        MotionService.shared.stopLiveUpdates()

        // Create a TimeEntry from the completed session
        let categoryDescriptor = FetchDescriptor<ActivityCategory>()
        let categories = (try? context.fetch(categoryDescriptor)) ?? []
        let category = categories.first { $0.name == session.categoryName }

        let entry = TimeEntry(
            startDate: session.startDate,
            endDate: session.endDate ?? Date(),
            category: category,
            source: .manual,
            confidence: 1.0,
            metadata: ["focusSessionId": session.id.uuidString]
        )
        context.insert(entry)

        try? context.save()
        activeSession = nil
        loadRecentSessions(context: context)
    }

    func discard(context: ModelContext) {
        guard let session = activeSession else { return }
        stopTimer()
        MotionService.shared.stopLiveUpdates()
        context.delete(session)
        activeSession = nil
        elapsedTime = 0
    }

    func loadRecentSessions(context: ModelContext) {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.startDate >= sevenDaysAgo && !session.isRunning
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        recentSessions = (try? context.fetch(descriptor)) ?? []
    }

    func resumeIfNeeded(context: ModelContext) {
        // Check if there's a running session (app was backgrounded)
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.isRunning
            }
        )
        if let running = (try? context.fetch(descriptor))?.first {
            activeSession = running
            elapsedTime = Date().timeIntervalSince(running.startDate)
            startTimer()
            MotionService.shared.startLiveUpdates()
        }
        loadRecentSessions(context: context)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let session = self.activeSession else { return }
            self.elapsedTime = Date().timeIntervalSince(session.startDate)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
