import EventKit
import SwiftData
import SwiftUI
import Foundation

enum CalendarImportService {

    struct ImportCandidate: Identifiable {
        let id: String
        let title: String
        let day: DayOfWeek
        let startTime: Date
        let endTime: Date
        let calendarTitle: String
    }

    struct CalendarInfo: Identifiable {
        let id: String          // EKCalendar.calendarIdentifier
        let title: String
        let color: Color
    }

    // MARK: - Authorization

    static var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    static func requestAccess(store: EKEventStore) async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    // MARK: - Available Calendars

    // Returns all writable event calendars on the device — excludes read-only
    // subscribed calendars (holidays, birthdays, sports) that users almost never
    // want imported into Nimva.
    static func availableCalendars(store: EKEventStore) -> [CalendarInfo] {
        store.calendars(for: .event)
            .filter { $0.allowsContentModifications || $0.type == .local || $0.type == .calDAV }
            .map { cal in
                CalendarInfo(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    color: Color(cgColor: cal.cgColor)
                )
            }
            .sorted { $0.title < $1.title }
    }

    // MARK: - Fetch

    // Returns timed (non-all-day) events for the current week that aren't
    // already in Nimva. Filters to selectedCalendarIDs when provided; falls
    // back to all calendars if none are selected.
    static func fetchCandidates(
        store: EKEventStore,
        existingEvents: [Event],
        selectedCalendarIDs: Set<String> = []
    ) -> [ImportCandidate] {
        let (start, end) = currentWeekRange()

        let filteredCalendars: [EKCalendar]?
        if selectedCalendarIDs.isEmpty {
            filteredCalendars = nil
        } else {
            filteredCalendars = store.calendars(for: .event)
                .filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
            if filteredCalendars?.isEmpty == true { return [] }
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: filteredCalendars)
        let ekEvents = store.events(matching: predicate)

        let existingKeys = Set(
            existingEvents
                .filter(\.isFixed)
                .compactMap { e -> String? in
                    guard let day = e.fixedDay else { return nil }
                    return dedupKey(name: e.name, day: day)
                }
        )

        return ekEvents.compactMap { ek -> ImportCandidate? in
            guard
                !ek.isAllDay,
                let title = ek.title,
                !title.trimmingCharacters(in: .whitespaces).isEmpty,
                let startDate = ek.startDate,
                let endDate = ek.endDate,
                let day = nimvaDay(from: startDate),
                !existingKeys.contains(dedupKey(name: title, day: day))
            else { return nil }

            return ImportCandidate(
                id: ek.eventIdentifier ?? UUID().uuidString,
                title: title,
                day: day,
                startTime: startDate,
                endTime: endDate,
                calendarTitle: ek.calendar?.title ?? ""
            )
        }
        .sorted { $0.day.rawValue < $1.day.rawValue }
    }

    // MARK: - Insert

    static func insert(_ candidates: [ImportCandidate], into context: ModelContext) {
        for c in candidates {
            let event = Event(
                name: c.title,
                isFixed: true,
                fixedDay: c.day,
                startTime: c.startTime,
                endTime: c.endTime,
                energyCost: 0.5
            )
            context.insert(event)
        }
        try? context.save()
    }

    // MARK: - Helpers

    static func dedupKey(name: String, day: DayOfWeek) -> String {
        "\(name.lowercased())_\(day.rawValue)"
    }

    // Week range always starts Monday regardless of device locale.
    private static func currentWeekRange() -> (start: Date, end: Date) {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let interval = cal.dateInterval(of: .weekOfYear, for: Date())
            ?? DateInterval(start: Date(), duration: 7 * 86400)
        return (interval.start, interval.end)
    }

    // Calendar.weekday: 1=Sun 2=Mon 3=Tue 4=Wed 5=Thu 6=Fri 7=Sat
    // DayOfWeek.rawValue: 1=Mon 2=Tue 3=Wed 4=Thu 5=Fri 6=Sat 7=Sun
    static func nimvaDay(from date: Date) -> DayOfWeek? {
        switch Calendar.current.component(.weekday, from: date) {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        case 1: return .sunday
        default: return nil
        }
    }
}
