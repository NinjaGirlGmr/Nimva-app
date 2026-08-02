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
        // Real calendar date of the (reference, for recurring) occurrence — discarded
        // before #86-era imports, now kept so one-off events can be anchored to their
        // single week via Event.specificDate.
        let specificDate: Date
        // From EKEvent.hasRecurrenceRules — true means this collapses every fetched
        // occurrence of the same series into one candidate (the "preset" behavior);
        // false means a genuine one-time event, imported with specificDate set.
        let isRecurring: Bool
    }

    // Thin, EventKit-touching intermediate — one per fetched EKEvent occurrence,
    // deliberately NOT importing EventKit types so the classification logic below
    // can be pure and unit-tested without a real EKEventStore.
    struct RawOccurrence {
        let id: String
        let title: String
        let day: DayOfWeek
        let startTime: Date
        let endTime: Date
        let calendarTitle: String
        let isRecurring: Bool
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

    // How many weeks ahead (including the current one) to pull from the calendar —
    // matches the rolling calendar's PRO ceiling (this week + 3). Fetched regardless
    // of the viewer's own PRO status: import scope and week-view gating stay decoupled,
    // so a free user's imported future events are simply there once they can view/build
    // that week.
    private static let importWeeksAhead = 4

    // Returns timed (non-all-day) events across the next several weeks that aren't
    // already in Nimva. Recurring calendar events collapse into a single candidate
    // regardless of how many weeks' worth of occurrences were fetched. Filters to
    // selectedCalendarIDs when provided; falls back to all calendars if none are selected.
    static func fetchCandidates(
        store: EKEventStore,
        existingEvents: [Event],
        selectedCalendarIDs: Set<String> = []
    ) -> [ImportCandidate] {
        let (start, end) = importRange()

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

        let occurrences: [RawOccurrence] = ekEvents.compactMap { ek in
            guard
                !ek.isAllDay,
                let title = ek.title,
                !title.trimmingCharacters(in: .whitespaces).isEmpty,
                let startDate = ek.startDate,
                let endDate = ek.endDate,
                let day = nimvaDay(from: startDate)
            else { return nil }

            return RawOccurrence(
                id: ek.eventIdentifier ?? UUID().uuidString,
                title: title,
                day: day,
                startTime: startDate,
                endTime: endDate,
                calendarTitle: ek.calendar?.title ?? "",
                isRecurring: ek.hasRecurrenceRules
            )
        }

        return classify(occurrences, existingEvents: existingEvents)
    }

    // MARK: - Classify & dedupe (pure — no EKEventStore needed, fully testable)

    // Splits fetched occurrences into recurring vs one-off, collapses every occurrence
    // of the same recurring series (EventKit expands a recurring event into one EKEvent
    // per week fetched) into a single candidate, and dedupes against events already in
    // Nimva. This is what turns "the same class fetched across 4 weeks" into one
    // selectable "preset" row instead of four near-duplicate ones.
    static func classify(_ occurrences: [RawOccurrence], existingEvents: [Event]) -> [ImportCandidate] {
        let existingRecurringKeys = Set(
            existingEvents
                .filter { $0.isFixed && $0.specificDate == nil }
                .compactMap { e -> String? in
                    guard let day = e.fixedDay else { return nil }
                    return dedupKey(name: e.name, day: day)
                }
        )
        let existingOneOffKeys = Set(
            existingEvents
                .filter { $0.isFixed }
                .compactMap { e -> String? in
                    guard let specific = e.specificDate else { return nil }
                    return dedupKey(name: e.name, specificDate: specific)
                }
        )

        let recurring = occurrences.filter(\.isRecurring)
        let oneOff = occurrences.filter { !$0.isRecurring }

        // Group recurring occurrences by (title, day, time-of-day) — one candidate per group.
        var recurringGroups: [String: RawOccurrence] = [:]
        for occ in recurring {
            let key = recurringGroupKey(title: occ.title, day: occ.day, startTime: occ.startTime)
            if recurringGroups[key] == nil { recurringGroups[key] = occ }
        }
        let recurringCandidates: [ImportCandidate] = recurringGroups.values.compactMap { occ in
            let key = dedupKey(name: occ.title, day: occ.day)
            guard !existingRecurringKeys.contains(key) else { return nil }
            return ImportCandidate(
                id: occ.id, title: occ.title, day: occ.day,
                startTime: occ.startTime, endTime: occ.endTime, calendarTitle: occ.calendarTitle,
                specificDate: occ.startTime, isRecurring: true
            )
        }

        // One-off occurrences are never collapsed — each is its own single event.
        let oneOffCandidates: [ImportCandidate] = oneOff.compactMap { occ in
            let key = dedupKey(name: occ.title, specificDate: occ.startTime)
            guard !existingOneOffKeys.contains(key) else { return nil }
            return ImportCandidate(
                id: occ.id, title: occ.title, day: occ.day,
                startTime: occ.startTime, endTime: occ.endTime, calendarTitle: occ.calendarTitle,
                specificDate: occ.startTime, isRecurring: false
            )
        }

        return (recurringCandidates + oneOffCandidates).sorted { $0.specificDate < $1.specificDate }
    }

    // Groups recurring occurrences by title + day-of-week + time-of-day, ignoring the
    // actual date — this is what collapses "Math Class" fetched in weeks 0-3 into one group.
    private static func recurringGroupKey(title: String, day: DayOfWeek, startTime: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        return "\(title.lowercased())_\(day.rawValue)_\(comps.hour ?? 0)_\(comps.minute ?? 0)"
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
                specificDate: c.isRecurring ? nil : c.specificDate,
                energyCost: 0.5
            )
            context.insert(event)
        }
        _ = try? context.save()
    }

    // MARK: - Helpers

    static func dedupKey(name: String, day: DayOfWeek) -> String {
        "\(name.lowercased())_\(day.rawValue)"
    }

    // Keyed by calendar day (not exact instant), so time-of-day differences on the
    // same date don't accidentally create duplicate imports of a moved one-off event.
    static func dedupKey(name: String, specificDate: Date) -> String {
        let day = Calendar.current.startOfDay(for: specificDate)
        return "\(name.lowercased())_\(Int(day.timeIntervalSince1970))"
    }

    // Multi-week range starting this Monday (regardless of device locale) through the
    // end of the importWeeksAhead-th week.
    // Reuses SchedulerService's own week-boundary logic instead of a second, independent
    // copy — this used to hardcode Monday as the week start regardless of device locale, so
    // on a Sunday (a new week for a US/Sunday-first locale) it would anchor the fetch window
    // to last Monday, sweeping in a full week of already-past events as import candidates
    // every time. Same root cause as the SchedulerService week-boundary fix, just duplicated
    // here in a separate implementation that didn't get touched by that fix.
    private static func importRange() -> (start: Date, end: Date) {
        let thisWeekStart = SchedulerService.weekStart()
        let end = SchedulerService.weekBoundaryCal.date(byAdding: .weekOfYear, value: importWeeksAhead, to: thisWeekStart) ?? thisWeekStart
        return (thisWeekStart, end)
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
