import Foundation
import SwiftData

// SchedulerService is the bridge between SwiftData (Event) and the pure algorithm (Scheduler).
// It handles mapping, runs the algorithm, and writes the result into WeekCache.
// Call regenerate(context:events:) whenever any event is added, edited, or deleted.

enum SchedulerService {

    // MARK: - Public API

    /// Runs the scheduling algorithm and persists the result as a WeekCache.
    ///
    /// - Parameter preservePastPlacements: When true (mid-week background rebuilds), flex events
    ///   already placed on past days are frozen and carried forward. When false (explicit Plan-tab
    ///   builds), the schedule is regenerated fresh from today onwards with no past placements.
    /// - Parameter weekOffset: Which week to build, in weeks from the current week (0 = this week,
    ///   1 = next week, etc.) — the rolling calendar feature. Defaults to 0 so every existing
    ///   caller (event edits, "Redo") keeps building the current week unchanged.
    ///
    /// Returns the WeekSchedule that was just computed (today-onwards only, not including
    /// any preserved past placements). The persisted cache always contains the full merged picture.
    @discardableResult
    static func regenerate(context: ModelContext, events: [Event], preservePastPlacements: Bool = true, weekOffset: Int = 0) throws -> WeekSchedule {
        // Defensive floor, not just a UI-layer assumption: a negative offset here would target
        // a genuine past week and silently overwrite real Insights history with a fresh
        // recompute. The UI already clamps at 0, but the data layer shouldn't rely solely on
        // that — this makes it structurally impossible regardless of caller behavior. A silent
        // clamp (not an assert) is deliberate: this path needs to degrade safely even in debug
        // builds, not trap — an assert here would crash before ever reaching the safety net.
        let weekOffset = max(0, weekOffset)

        let targetStart = weekStart(offsetWeeks: weekOffset)
        let todayWeekStart = weekStart()

        // Logged events count toward that day's real load the same way fixed events do —
        // they already happened, on a specific day, so they're folded into the same `fixed`
        // array rather than the placement algorithm treating them as something to schedule.
        let fixed = events.compactMap { toFixedEvent($0, weekStart: targetStart) }
            + events.compactMap { toLoggedFixedEvent($0, weekStart: targetStart) }
        // Same visibility rule as fixed events: a "this week only" flexible event
        // (Event.specificDate set) is only ever a placement candidate for its own week.
        // wasLogged events are excluded here — they're never a placement candidate at all,
        // since they already happened on a known day, not something the algorithm should
        // be free to move.
        let flexible = events
            .filter { !$0.isFixed && !$0.wasLogged && isEventVisible($0, inWeekStarting: targetStart) }
            .compactMap { toFlexibleEvent($0) }
        let isCurrentWeek = weekBoundaryCal.isDate(targetStart, equalTo: todayWeekStart, toGranularity: .weekOfYear)
        // Future weeks have no "past days" yet, so always start from Monday — this also
        // naturally empties pastRecords/idsInPast below without a separate branch.
        let today = isCurrentWeek ? todayAsDayOfWeek() : .monday
        let existing = try context.fetch(FetchDescriptor<WeekCache>())
        let priorCache = existing.first {
            weekBoundaryCal.isDate($0.weekStartDate, equalTo: targetStart, toGranularity: .weekOfYear)
        }

        // Extract placements from days that have already passed so they survive the rebuild.
        // Only applies when called from background rebuilds (event edits), not explicit Plan-tab builds.
        //
        // Use rawValue (Mon=1 … Sun=7) for the "is this day past?" check, NOT orderedForLocale.
        // In US locale, orderedForLocale puts Sunday at index 0 (before Monday), which would
        // cause Sunday (rawValue 7) to be treated as "past" on any Mon–Sat day — but Sunday is
        // the LAST day of the internal Mon–Sun week and is always future until Sunday itself.
        // rawValue comparison gives the correct temporal order for both US and ISO locales:
        //   today = Wednesday (rawValue 3) → past = Mon(1), Tue(2); Sun(7) is NOT past.
        var pastRecords: [PlacementRecord] = []
        var idsInPast: Set<UUID> = []
        if preservePastPlacements,
           let prior = priorCache,
           let data = prior.placementsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([PlacementRecord].self, from: data) {
            for record in decoded {
                if let day = DayOfWeek(rawValue: record.dayRawValue),
                   day.rawValue < today.rawValue {
                    pastRecords.append(record)
                    idsInPast.insert(record.eventId)
                }
            }
        }

        // Only re-schedule events not already locked into a past day
        let flexToSchedule = flexible.filter { !idsInPast.contains($0.id) }
        let result = Scheduler.generateWeek(fixed: fixed, flexible: flexToSchedule, startingFrom: today)

        // Merge past-day records with newly placed events for the persisted cache
        let newRecords = result.placedFlexibleEvents.map {
            PlacementRecord(eventId: $0.event.id, dayRawValue: $0.day.rawValue, reason: $0.reason)
        }
        let mergedData = try JSONEncoder().encode(pastRecords + newRecords)
        let json = String(data: mergedData, encoding: .utf8) ?? "[]"

        let heavyDayValues = result.heavyDays.map { $0.rawValue }

        // Replace only this week's cache — older weeks are kept for Insights history
        existing
            .filter { weekBoundaryCal.isDate($0.weekStartDate, equalTo: targetStart, toGranularity: .weekOfYear) }
            .forEach { context.delete($0) }

        let cache = WeekCache(
            weekStartDate: targetStart,
            placementsJSON: json,
            balanceScore: result.balanceScore,
            heavyDayValues: heavyDayValues
        )
        cache.wasRecoveryWeek = isLightWeek(events: events)
        // Carry forward user data that must survive event edits
        cache.completedEventIdsJSON = priorCache?.completedEventIdsJSON ?? "[]"
        cache.checkInRating = priorCache?.checkInRating
        cache.checkInHardestDayRawValue = priorCache?.checkInHardestDayRawValue
        cache.checkInCompletedAt = priorCache?.checkInCompletedAt
        cache.recoveryCheckInRaw = priorCache?.recoveryCheckInRaw
        // Experiment: keep the same suggestion if one was already set this week;
        // pick a new one (deterministic by date) for fresh light weeks.
        if cache.wasRecoveryWeek {
            cache.experimentText = priorCache?.experimentText ?? pickExperiment(for: targetStart)
        }
        cache.experimentTriedRaw = priorCache?.experimentTriedRaw
        context.insert(cache)

        // Trim history to 8 weeks so SwiftData doesn't accumulate unbounded records —
        // bucketed separately from future (rolling-calendar) weeks so building ahead never
        // eats into the history Insights needs. Both buckets computed relative to the real
        // current week, not whichever week was just built.
        let all = try context.fetch(FetchDescriptor<WeekCache>(sortBy: [SortDescriptor(\.weekStartDate, order: .reverse)]))
        let history = all.filter { $0.weekStartDate <= todayWeekStart }
        if history.count > 8 {
            history.dropFirst(8).forEach { context.delete($0) }
        }
        // Defensive cap — the rolling calendar UI enforces at most 3 weeks ahead, but the
        // data layer shouldn't silently trust that; keep only the 3 nearest future weeks.
        // `all` (and therefore this filtered slice) is sorted furthest-future-first, so it
        // must be re-sorted nearest-first before dropFirst(3) — otherwise dropFirst keeps
        // the *furthest* 3 and deletes the nearest ones, which is exactly backwards.
        let future = all
            .filter { $0.weekStartDate > todayWeekStart }
            .sorted { $0.weekStartDate < $1.weekStartDate }
        if future.count > 3 {
            future.dropFirst(3).forEach { context.delete($0) }
        }

        // Explicit save — every other mutation in the app (completion cycling, calendar
        // import, intention deletion) saves immediately; this was the one place relying
        // on autosave timing. Without it, a build could exist only in memory: correct in
        // the view that just built it, but lost if the app is force-quit before an autosave
        // trigger fires, and not guaranteed to be visible to sibling views in the meantime.
        try context.save()

        return result
    }

    /// Reads a cached schedule and decodes it back into a WeekSchedule.
    /// - Parameter weekOffset: Which week to load, in weeks from the current week (0 = this week).
    /// Returns nil if no cache exists yet for that week (caller should trigger regenerate).
    static func loadCachedSchedule(context: ModelContext, events: [Event], weekOffset: Int = 0) throws -> WeekSchedule? {
        // Silent clamp, not an assert — see regenerate's matching comment.
        let weekOffset = max(0, weekOffset)
        let targetStart = weekStart(offsetWeeks: weekOffset)
        let descriptor = FetchDescriptor<WeekCache>(sortBy: [SortDescriptor(\.weekStartDate, order: .reverse)])
        let caches = try context.fetch(descriptor)

        // Search for the matching week — don't assume the newest row is the one wanted,
        // since multiple weeks (this week + rolling-calendar future weeks) can coexist.
        guard let cache = caches.first(where: {
            weekBoundaryCal.isDate($0.weekStartDate, equalTo: targetStart, toGranularity: .weekOfYear)
        }) else { return nil }

        let placements = try decodePlacements(cache.placementsJSON, events: events)
        let fixed = events.compactMap { toFixedEvent($0, weekStart: targetStart) }
        let dailyLoads = computeDailyLoads(fixed: fixed, placed: placements)
        let heavyDays = Set(cache.heavyDayValues.compactMap { DayOfWeek(rawValue: $0) })

        return WeekSchedule(
            fixedEvents: fixed,
            placedFlexibleEvents: placements,
            overflowEvents: [],   // overflow isn't persisted; re-run if needed
            dailyLoads: dailyLoads,
            balanceScore: cache.balanceScore,
            heavyDays: heavyDays
        )
    }

    // MARK: - Current week cache lookup

    /// Finds the cache matching the current week among all caches — searches rather than
    /// assuming the newest row is the one wanted. A stale future-week cache (from building
    /// ahead via the rolling calendar) would otherwise sort as "newest" and be mistaken for
    /// "nothing's been built yet" even when a valid current-week cache exists elsewhere in
    /// the list. Same class of bug already fixed once in loadCachedSchedule — this is the
    /// shared, testable version so it isn't duplicated (and re-broken) inline per caller.
    static func currentWeekCache(from caches: [WeekCache]) -> WeekCache? {
        caches.first {
            weekBoundaryCal.isDate($0.weekStartDate, equalTo: weekStart(), toGranularity: .weekOfYear)
        }
    }

    // MARK: - Recurring-pattern detection

    /// True when a flexible event named `name` has been added as "this week only" in
    /// `consecutiveWeeks` (default 3) consecutive weeks, including the current one.
    /// Checked right after saving a new one-off flexible event, to offer converting it
    /// to recurring instead of requiring manual re-entry every week.
    static func hasRecurringPattern(name: String, events: [Event], consecutiveWeeks: Int = 3) -> Bool {
        let target = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !target.isEmpty else { return false }
        let matchingWeeks = Set(events.compactMap { event -> Date? in
            guard !event.isFixed, let specific = event.specificDate,
                  event.name.trimmingCharacters(in: .whitespaces).lowercased() == target
            else { return nil }
            return weekStart(for: specific)
        })
        for i in 0..<consecutiveWeeks {
            guard matchingWeeks.contains(weekStart(offsetWeeks: -i)) else { return false }
        }
        return true
    }

    // MARK: - Day query

    /// Returns all events scheduled on a given day — fixed events anchored there, plus
    /// flexible events the algorithm placed there. Used by HomeView to populate the day list.
    static func events(for day: DayOfWeek, cache: WeekCache, from events: [Event]) -> [Event] {
        let fixed = events.filter {
            $0.isFixed && $0.fixedDay == day && isEventVisible($0, inWeekStarting: cache.weekStartDate)
        }
        let logged = events.filter { isLoggedEventVisible($0, onDay: day, inWeekStarting: cache.weekStartDate) }
        let placedIds = flexibleIds(for: day, in: cache.placementsJSON)
        // wasLogged is excluded here even though placedIds would never contain one (they're
        // never fed to regenerate) — explicit for the same reason the flexible filter in
        // regenerate() is explicit: it shouldn't depend on that invariant holding elsewhere.
        let flexible = events.filter { !$0.isFixed && !$0.wasLogged && placedIds.contains($0.id) }
        return fixed + logged + flexible
    }

    /// A logged event's visibility isn't placement-dependent (it's never in a cache's
    /// placementsJSON — see toLoggedFixedEvent) — it's visible on whichever day its
    /// specificDate actually falls on, the same way a date-anchored fixed event is.
    static func isLoggedEventVisible(_ event: Event, onDay day: DayOfWeek, inWeekStarting weekStart: Date) -> Bool {
        guard event.wasLogged, let specific = event.specificDate,
              CalendarImportService.nimvaDay(from: specific) == day
        else { return false }
        return isEventVisible(event, inWeekStarting: weekStart)
    }

    // MARK: - Date-specific fixed events (multi-week calendar import)

    /// True when a fixed event should appear in the given week. Recurring events
    /// (specificDate == nil — the default, covering every manually-added or
    /// previously-imported event) are visible every week. Date-anchored events (a
    /// one-off calendar import) are visible only in the single week containing that date.
    static func isEventVisible(_ event: Event, inWeekStarting weekStart: Date) -> Bool {
        guard let specific = event.specificDate else { return true }
        return weekBoundaryCal.isDate(specific, equalTo: weekStart, toGranularity: .weekOfYear)
    }

    /// Detects which user type this schedule represents based on the fixed/flexible ratio.
    /// Needs at least 4 events to make a meaningful call; defaults to .optimizer with fewer.
    static func detectUserType(events: [Event]) -> UserType {
        guard events.count >= 4 else { return .optimizer }
        let fixedCount = events.filter(\.isFixed).count
        let ratio = Double(fixedCount) / Double(events.count)
        if ratio >= 0.9 { return .overloadedFixed }
        if ratio >= 0.6 { return .patternLearner }
        return .optimizer
    }

    /// Returns the count of flexible events that couldn't be placed (overflow).
    static func overflowCount(cache: WeekCache, totalFlexible: Int) -> Int {
        guard let data = cache.placementsJSON.data(using: .utf8),
              let records = try? JSONDecoder().decode([PlacementRecord].self, from: data)
        else { return 0 }
        return max(0, totalFlexible - records.count)
    }

    // Decodes placement JSON and returns the event IDs placed on the given day
    private static func flexibleIds(for day: DayOfWeek, in json: String) -> Set<UUID> {
        guard let data = json.data(using: .utf8),
              let records = try? JSONDecoder().decode([PlacementRecord].self, from: data)
        else { return [] }
        return Set(records.filter { $0.dayRawValue == day.rawValue }.map { $0.eventId })
    }

    // MARK: - Completion state (#83)

    /// Three-state completion tracking — richer than a binary done/not-done, since ADHD
    /// task-switching and OCD all-or-nothing thinking are both worsened by forcing an
    /// interrupted task into either "done" or "failed."
    enum EventCompletionState: String, Codable {
        case notStarted
        case inProgress
        case completed
    }

    /// Reads an event's current completion state from the cache's two ID-set fields.
    static func completionState(for eventId: UUID, cache: WeekCache) -> EventCompletionState {
        if idSet(from: cache.completedEventIdsJSON).contains(eventId) { return .completed }
        if idSet(from: cache.inProgressEventIdsJSON).contains(eventId) { return .inProgress }
        return .notStarted
    }

    /// Advances an event one step: not started → in progress → completed → not started.
    /// Returns the two JSON strings to write back — the sets are always mutually exclusive.
    static func cycledCompletionJSON(
        for eventId: UUID,
        completedJSON: String,
        inProgressJSON: String
    ) -> (completed: String, inProgress: String) {
        var completed = idSet(from: completedJSON)
        var inProgress = idSet(from: inProgressJSON)

        if completed.contains(eventId) {
            completed.remove(eventId)
        } else if inProgress.contains(eventId) {
            inProgress.remove(eventId)
            completed.insert(eventId)
        } else {
            inProgress.insert(eventId)
        }

        return (encodeIds(completed), encodeIds(inProgress))
    }

    /// True when marking `event` "completed" right now would mean marking something that
    /// hasn't actually happened yet — a genuinely future day this week, or (for fixed events
    /// specifically, the only ones with a real clock time) later today. Flexible events have
    /// no specific hour, so "today" is the finest granularity available for them; a flexible
    /// event on today is never considered premature. Callers use this to add a confirmation
    /// step before the tap that would produce the strikethrough+checkmark "completed" state —
    /// that visual reads as "this happened," so it shouldn't apply silently to something that
    /// demonstrably hasn't, while still letting the user confirm and mark it done anyway if
    /// that's genuinely what they mean (e.g. they finished it early).
    static func isCompletionPremature(
        event: Event,
        selectedDay: DayOfWeek,
        today: DayOfWeek,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        if selectedDay.rawValue > today.rawValue { return true }
        if selectedDay.rawValue < today.rawValue { return false }
        guard event.isFixed, let start = event.startTime else { return false }
        // startTime only carries a meaningful time-of-day for a recurring fixed event (see
        // minuteOfDay in RecoveryWindows.swift) — compare minute-of-day, never full Dates.
        return minuteOfDay(start, calendar: calendar) > minuteOfDay(now, calendar: calendar)
    }

    private static func idSet(from json: String) -> Set<UUID> {
        guard let data = json.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    private static func encodeIds(_ ids: Set<UUID>) -> String {
        guard let data = try? JSONEncoder().encode(ids.map(\.uuidString)),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }

    // MARK: - Mapping: SwiftData Event → pure structs

    private static func toFixedEvent(_ event: Event, weekStart: Date) -> FixedEvent? {
        guard event.isFixed, let day = event.fixedDay, isEventVisible(event, inWeekStarting: weekStart)
        else { return nil }
        return FixedEvent(id: event.id, name: event.name, day: day, energyCost: event.energyCost)
    }

    /// A logged (retroactive) event contributes to its day's load exactly like a fixed
    /// event does — it's certain, already happened, and isn't a placement candidate — so it
    /// gets folded into the same `[FixedEvent]` array the algorithm already sums by day,
    /// rather than needing a separate load-summing path.
    private static func toLoggedFixedEvent(_ event: Event, weekStart: Date) -> FixedEvent? {
        guard event.wasLogged, let specific = event.specificDate,
              let day = CalendarImportService.nimvaDay(from: specific),
              isEventVisible(event, inWeekStarting: weekStart)
        else { return nil }
        return FixedEvent(id: event.id, name: event.name, day: day, energyCost: event.energyCost)
    }

    private static func toFlexibleEvent(_ event: Event) -> FlexibleEvent? {
        guard !event.isFixed else { return nil }
        let window = event.preferredWindow ?? .any
        return FlexibleEvent(id: event.id, name: event.name, preferredWindow: window, energyCost: event.energyCost, isPriority: event.isPriority)
    }

    // MARK: - JSON encode/decode for placements

    // Lightweight struct just for persistence — IDs, day values, and the placement reason.
    // reason is optional for backwards compatibility with caches written before #62.
    private struct PlacementRecord: Codable {
        let eventId: UUID
        let dayRawValue: Int
        let reason: String?
    }

    private static func encodePlacements(_ placed: [PlacedEvent]) throws -> String {
        let records = placed.map {
            PlacementRecord(eventId: $0.event.id, dayRawValue: $0.day.rawValue, reason: $0.reason)
        }
        let data = try JSONEncoder().encode(records)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func decodePlacements(_ json: String, events: [Event]) throws -> [PlacedEvent] {
        guard let data = json.data(using: .utf8) else { return [] }
        let records = try JSONDecoder().decode([PlacementRecord].self, from: data)

        // Re-hydrate each record by matching the stored eventId back to a live Event
        return records.compactMap { record in
            guard
                let event = events.first(where: { $0.id == record.eventId }),
                let day = DayOfWeek(rawValue: record.dayRawValue),
                let flex = toFlexibleEvent(event)
            else { return nil }
            return PlacedEvent(event: flex, day: day, reason: record.reason ?? "")
        }
    }

    /// Returns a map of flexible event UUID → placement reason for display in the UI.
    /// Returns an empty dict if the cache can't be decoded.
    static func placementReasons(in cache: WeekCache) -> [UUID: String] {
        guard let data = cache.placementsJSON.data(using: .utf8),
              let records = try? JSONDecoder().decode([PlacementRecord].self, from: data)
        else { return [:] }
        var result: [UUID: String] = [:]
        for record in records {
            if let reason = record.reason, !reason.isEmpty {
                result[record.eventId] = reason
            }
        }
        return result
    }

    // MARK: - Helpers

    private static func computeDailyLoads(fixed: [FixedEvent], placed: [PlacedEvent]) -> [DayOfWeek: Double] {
        var loads: [DayOfWeek: Double] = Dictionary(uniqueKeysWithValues: DayOfWeek.allCases.map { ($0, 0.0) })
        for e in fixed  { loads[e.day, default: 0.0] += e.energyCost }
        for p in placed { loads[p.day, default: 0.0] += p.event.energyCost }
        return loads
    }

    /// Returns the most recent Monday at midnight — used as the canonical week identifier.
    static func weekStart(for date: Date = Date()) -> Date {
        return weekBoundaryCal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    /// Returns the Monday of the week `offsetWeeks` weeks from now (0 = this week, 1 = next
    /// week, etc.) — the rolling calendar feature's target-week lookup. Uses Calendar arithmetic
    /// rather than raw time-interval math so it stays correct across DST transitions.
    static func weekStart(offsetWeeks: Int) -> Date {
        let base = weekBoundaryCal.date(byAdding: .weekOfYear, value: offsetWeeks, to: Date()) ?? Date()
        return weekStart(for: base)
    }

    /// The week-boundary calendar used for every "which week is this" comparison —
    /// derives firstWeekday from the real device locale (Sunday for US, Monday for most
    /// of Europe, etc.), matching DayOfWeek.orderedForLocale's own convention. Previously
    /// hardcoded to Monday regardless of locale, which meant a US user's Sunday was still
    /// classified as the tail end of last week instead of the start of a new one.
    static var weekBoundaryCal: Calendar {
        Calendar.current
    }

    /// True when the total energy load is low enough that the week feels "open."
    /// Below a single heavy-day's worth of energy across all events.
    static func isLightWeek(events: [Event]) -> Bool {
        guard !events.isEmpty else { return false }
        let totalCost = events.reduce(0.0) { $0 + $1.energyCost }
        return totalCost < Scheduler.heavyDayThreshold
    }

    // MARK: - Energy experiments

    // Curated list of small, low-stakes behavioral nudges for light weeks.
    // Rotates deterministically by week so the same week always gets the same suggestion.
    private static let experiments: [String] = [
        "Try ending your last event of the day by 7pm — see if evenings feel different.",
        "Take a 5-minute break between every back-to-back event.",
        "Pick one evening this week with no agenda — nothing scheduled, nothing planned.",
        "Start your lightest task first thing each morning, before anything else.",
        "Keep the first 30 minutes of your morning screen-free.",
        "Try eating lunch somewhere other than your desk or phone.",
        "Set a consistent time to stop working — and actually stop at that time.",
        "Spend at least 10 minutes outside each day, even just briefly.",
        "Say no to one optional commitment you'd normally say yes to.",
        "Write down one thing you're glad happened at the end of each day.",
        "Turn notifications off for one 2-hour block each day.",
        "Do your hardest task when your energy is highest — notice when that is.",
    ]

    private static func pickExperiment(for weekStart: Date) -> String {
        // Use week index since epoch so the same week always returns the same suggestion.
        let weekIndex = Int(weekStart.timeIntervalSince1970 / (7 * 24 * 3600))
        return experiments[abs(weekIndex) % experiments.count]
    }

    // Calendar.weekday: 1=Sun 2=Mon 3=Tue 4=Wed 5=Thu 6=Fri 7=Sat
    // DayOfWeek.rawValue: 1=Mon … 7=Sun
    // internal (not private) — WeekGenerationView reads this for the rolling-calendar access check.
    static func todayAsDayOfWeek() -> DayOfWeek {
        switch Calendar.current.component(.weekday, from: Date()) {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }
}
