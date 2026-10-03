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

    // Adds (doesn't replace) a single realistic candidate-time-window scenario (#79/#80) —
    // the exact example from the issue itself: a club meeting either 8:00-8:30am or
    // 3:45-4:15pm. Pairs it with a draining class tight against the morning slot, so
    // "Build my week" has a genuinely demonstrable winner to pick (the afternoon slot) rather
    // than an arbitrary tie. Removes any previously-seeded copy of itself first, so tapping
    // this repeatedly during testing doesn't pile up duplicates.
    //
    // Deliberately anchored to *today*, not a hardcoded weekday — isDayPast (SchedulerService)
    // skips resolving a candidate-window event once its day has already passed this week, and
    // the whole point of this button is "build right now and immediately see it resolve,"
    // regardless of which real-world day testing happens to be run on.
    //
    // Also resets hasSeenCandidateWindowTutorial so #80's one-time explainer can be re-tested
    // on the next approval, not just the very first one ever.
    static func seedCandidateWindowDemo(context: ModelContext) {
        let testMarker = "Club (candidate-window test)"
        let existing = (try? context.fetch(FetchDescriptor<Event>(predicate: #Predicate { $0.name == testMarker }))) ?? []
        existing.forEach { context.delete($0) }

        let today = SchedulerService.todayAsDayOfWeek()
        let morningStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let morningEnd = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!
        let afternoonStart = Calendar.current.date(bySettingHour: 15, minute: 45, second: 0, of: Date())!
        let afternoonEnd = Calendar.current.date(bySettingHour: 16, minute: 15, second: 0, of: Date())!

        let club = Event(
            name: testMarker,
            isFixed: true,
            fixedDay: today,
            startTime: morningStart,   // pre-build default — gets overwritten by the resolved pick
            endTime: morningEnd,
            energyCost: 0.4,
            category: "Social",
            candidateStartTimes: [morningStart, afternoonStart],
            candidateEndTimes: [morningEnd, afternoonEnd]
        )
        let morningClass = Event(
            name: "Morning Class (candidate-window test)",
            isFixed: true,
            fixedDay: today,
            startTime: Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!,
            endTime: Calendar.current.date(bySettingHour: 9, minute: 15, second: 0, of: Date())!,
            energyCost: 0.9,
            category: "School"
        )
        context.insert(club)
        context.insert(morningClass)
        try? context.save()

        UserDefaults.standard.set(false, forKey: "hasSeenCandidateWindowTutorial")
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

        // dailyLoads: Mon, Tue, Wed, Thu, Fri, Sat, Sun — deliberately varied across all
        // three severity tiers (not just heavy/light) so the Insights day-breakdown bar
        // chart and day-pattern grid both have something real to show, not a flat line.
        // Values are hand-picked to roughly agree with each week's heavyDays list, not
        // derived from the actual algorithm — this is demo data, not a simulation.
        let history: [(weeksAgo: Int, heavyDays: [DayOfWeek], dailyLoads: [Double], balance: Double, rating: Double?, hardestDay: DayOfWeek?)] = [
            (6, [.tuesday, .thursday], [0.9, 2.3, 1.4, 2.1, 0.5, 0.0, 0.3], 2.1, 0.80, .tuesday),
            (5, [.tuesday, .wednesday],[1.2, 2.4, 2.0, 1.3, 0.4, 0.0, 0.2], 1.8, 0.67, .tuesday),
            (4, [.tuesday],            [0.8, 2.2, 1.5, 0.9, 1.1, 0.0, 0.0], 1.2, 0.50, nil),
            (3, [.tuesday, .friday],   [1.3, 2.5, 0.7, 1.4, 2.1, 0.2, 0.0], 2.3, 0.85, .tuesday),
            (2, [.tuesday],            [0.9, 2.0, 1.6, 0.8, 0.5, 0.0, 0.1], 1.5, 0.33, .tuesday),
            (1, [.tuesday, .thursday], [1.1, 2.3, 0.6, 2.2, 0.4, 0.0, 0.0], 1.9, 0.67, .tuesday),
            (0, [.tuesday],            [0.8, 2.1, 1.3, 0.7, 0.5, 0.0, 0.0], 1.3, nil,  nil),   // current week — no check-in yet
        ]

        return history.map { entry in
            let start = weekStart(weeksAgo: entry.weeksAgo)
            let cache = WeekCache(
                weekStartDate: start,
                placementsJSON: placementsJSON,
                balanceScore: entry.balance,
                heavyDayValues: entry.heavyDays.map(\.rawValue),
                dailyLoadValues: entry.dailyLoads
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
