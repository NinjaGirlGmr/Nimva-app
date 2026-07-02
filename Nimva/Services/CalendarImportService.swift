import EventKit
import SwiftData
import Foundation

enum CalendarImportService {

    struct ImportCandidate: Identifiable {
        let id: String          // EKEvent.eventIdentifier — stable across fetches
        let title: String
        let day: DayOfWeek
        let startTime: Date
        let endTime: Date
    }

    // MARK: - Authorization

    static var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17, *) { return status == .fullAccess }
        return status == .authorized
    }

    static func requestAccess(store: EKEventStore) async -> Bool {
        if #available(iOS 17, *) {
            return (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            return await withCheckedContinuation { cont in
                store.requestAccess(to: .event) { granted, _ in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Fetch

    // Returns timed (non-all-day) calendar events for the current week that
    // don't already exist in Nimva. Sorted by day so the review sheet reads
    // Mon → Sun naturally.
    static func fetchCandidates(store: EKEventStore, existingEvents: [Event]) -> [ImportCandidate] {
        let (start, end) = currentWeekRange()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
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
                endTime: endDate
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

    private static func dedupKey(name: String, day: DayOfWeek) -> String {
        "\(name.lowercased())_\(day.rawValue)"
    }

    private static func currentWeekRange() -> (start: Date, end: Date) {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let interval = cal.dateInterval(of: .weekOfYear, for: Date())
            ?? DateInterval(start: Date(), duration: 7 * 86400)
        return (interval.start, interval.end)
    }

    // Calendar.weekday: 1=Sun 2=Mon 3=Tue 4=Wed 5=Thu 6=Fri 7=Sat
    // DayOfWeek.rawValue: 1=Mon 2=Tue 3=Wed 4=Thu 5=Fri 6=Sat 7=Sun
    private static func nimvaDay(from date: Date) -> DayOfWeek? {
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
