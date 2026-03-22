import Foundation
import EventKit

@Observable
final class CalendarService {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()
    private(set) var isAuthorized = false

    // MARK: - Authorization

    func requestAuthorization() async throws {
        let granted = try await eventStore.requestFullAccessToEvents()
        isAuthorized = granted
    }

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Fetch Events

    func fetchEvents(for date: Date) -> [CalendarEvent] {
        guard isAuthorized || authorizationStatus == .fullAccess else { return [] }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)

        return events.compactMap { event in
            // Skip all-day events — they don't represent actual time blocks
            guard !event.isAllDay else { return nil }
            // Skip cancelled events
            guard event.status != .canceled else { return nil }

            return CalendarEvent(
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarName: event.calendar?.title ?? "Unknown",
                location: event.location
            )
        }
    }

    func fetchEventsForRange(start: Date, end: Date) -> [CalendarEvent] {
        guard isAuthorized || authorizationStatus == .fullAccess else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        return events.compactMap { event in
            guard !event.isAllDay else { return nil }
            guard event.status != .canceled else { return nil }

            return CalendarEvent(
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarName: event.calendar?.title ?? "Unknown",
                location: event.location
            )
        }
    }

    // MARK: - Meeting Time

    func totalMeetingMinutes(for date: Date) -> Int {
        let events = fetchEvents(for: date)
        return events.reduce(0) { total, event in
            total + Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        }
    }
}

// MARK: - Supporting Types

struct CalendarEvent {
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarName: String
    let location: String?

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
}
