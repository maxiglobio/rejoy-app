import Foundation
import EventKit

@MainActor
final class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()

    func requestAuthorization() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                try await eventStore.requestFullAccessToEvents()
                return true
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { cont in
                eventStore.requestAccess(to: .event) { granted, _ in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    func fetchTodayEvents() async -> [String: Double] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        var endOfDay = startOfDay
        if let end = calendar.date(byAdding: .day, value: 1, to: startOfDay) {
            endOfDay = end
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)

        var result: [String: Double] = [:]
        for event in events {
            let minutes = event.endDate.timeIntervalSince(event.startDate) / 60
            let calendarName = event.calendar?.title ?? "Calendar"
            let key = "\(calendarName): \(event.title ?? "Event")"
            result[key, default: 0] += minutes
        }

        // Also group by calendar for summary
        var byCalendar: [String: Double] = [:]
        for event in events {
            let minutes = event.endDate.timeIntervalSince(event.startDate) / 60
            let calendarName = event.calendar?.title ?? "Calendar"
            byCalendar[calendarName, default: 0] += minutes
        }
        return byCalendar.isEmpty ? result : byCalendar
    }
}
