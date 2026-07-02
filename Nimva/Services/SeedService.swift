#if DEBUG
import Foundation
import SwiftData

// Injects realistic synthetic data so every screen can be tested without
// manually entering events each time. Only compiled in DEBUG builds.
enum SeedService {

    // Wipes all existing events and week history, then inserts a full
    // synthetic dataset: mixed fixed/flexible events, 7 weeks of WeekCache
    // history with deliberate Tuesday-heavy pattern to trigger Insights callout,
    // and the current week left without a check-in so the banner appears.
    static func seed(context: ModelContext) {
        try? context.delete(model: Event.self)
        try? context.delete(model: WeekCache.self)

        let events = makeSampleEvents()
        events.forEach { context.insert($0) }

        let flexEvents = events.filter { !$0.isFixed }
        makeWeekHistory(flexEvents: flexEvents).forEach { context.insert($0) }

        try? context.save()
    }

    // MARK: - Events

    private static func makeSampleEvents() -> [Event] {
        [
            // ── Fixed events ──────────────────────────────────────────────
            // Tuesday is deliberately loaded (English + Biology + Soccer)
            // so the pattern callout fires in Insights after enough weeks.
            Event(name: "Math Class",    isFixed: true, fixedDay: .monday,    energyCost: 0.75, category: "School"),
            Event(name: "English Class", isFixed: true, fixedDay: .tuesday,   energyCost: 0.50, category: "School"),
            Event(name: "Biology Lab",   isFixed: true, fixedDay: .tuesday,   energyCost: 0.85, category: "School"),
            Event(name: "Soccer Practice",isFixed:true, fixedDay: .tuesday,   energyCost: 0.65, category: "Sports"),
            Event(name: "Math Class",    isFixed: true, fixedDay: .wednesday,  energyCost: 0.75, category: "School"),
            Event(name: "History",       isFixed: true, fixedDay: .thursday,  energyCost: 0.50, category: "School"),
            Event(name: "Soccer Practice",isFixed:true, fixedDay: .thursday,  energyCost: 0.65, category: "Sports"),
            Event(name: "Study Hall",    isFixed: true, fixedDay: .friday,    energyCost: 0.25, category: "School"),

            // ── Flexible events ───────────────────────────────────────────
            Event(name: "Study session", isFixed: false, preferredWindow: .afternoon, energyCost: 0.75, category: "School"),
            Event(name: "Read for fun",  isFixed: false, preferredWindow: .evening,   energyCost: 0.25, category: "Personal"),
            Event(name: "Gym",           isFixed: false, preferredWindow: .morning,   energyCost: 0.50, category: "Sports"),
            Event(name: "Work on project",isFixed:false, preferredWindow: .any,       energyCost: 0.85, category: "School"),
        ]
    }

    // MARK: - Week history

    // Produces 7 WeekCache records: 6 past weeks (checked in) + current week
    // (no check-in, so the banner appears on the home screen).
    // Tuesday is flagged heavy in 5 of the 6 past weeks — enough to trigger
    // the Insights pattern callout ("Tuesdays have been consistently heavy").
    private static func makeWeekHistory(flexEvents: [Event]) -> [WeekCache] {
        let placementsJSON = makePlacementsJSON(flexEvents: flexEvents)

        let history: [(weeksAgo: Int, heavyDays: [DayOfWeek], balance: Double, rating: Double?, hardestDay: DayOfWeek?)] = [
            (6, [.tuesday, .thursday], 2.1, 0.80, .tuesday),
            (5, [.tuesday, .wednesday],1.8, 0.67, .tuesday),
            (4, [.tuesday],            1.2, 0.50, nil),
            (3, [.tuesday, .friday],   2.3, 0.85, .tuesday),
            (2, [.tuesday],            1.5, 0.33, .tuesday),
            (1, [.tuesday, .thursday], 1.9, 0.67, .tuesday),
            (0, [.tuesday],            1.3, nil,  nil),   // current week — no check-in yet
        ]

        return history.map { entry in
            let start = weekStart(weeksAgo: entry.weeksAgo)
            let cache = WeekCache(
                weekStartDate: start,
                placementsJSON: placementsJSON,
                balanceScore: entry.balance,
                heavyDayValues: entry.heavyDays.map(\.rawValue)
            )
            cache.checkInRating = entry.rating
            cache.checkInHardestDayRawValue = entry.hardestDay?.rawValue
            cache.checkInCompletedAt = entry.rating != nil ? start.addingTimeInterval(6 * 24 * 3600) : nil
            return cache
        }
    }

    // Places flex events across Mon/Wed/Fri to produce a plausible placement JSON
    // that HomeView can decode to show events in the day list.
    private static func makePlacementsJSON(flexEvents: [Event]) -> String {
        struct Record: Codable { let eventId: UUID; let dayRawValue: Int }
        let days: [DayOfWeek] = [.monday, .wednesday, .friday, .monday]
        let placements = zip(flexEvents, days).map { event, day in
            Record(eventId: event.id, dayRawValue: day.rawValue)
        }
        let data = (try? JSONEncoder().encode(placements)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    // Returns the Monday that starts the week N weeks ago
    private static func weekStart(weeksAgo: Int) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeek) ?? thisWeek
    }
}
#endif
