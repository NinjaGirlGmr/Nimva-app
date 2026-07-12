import Foundation
import SwiftData

// SchedulerService is the bridge between SwiftData (Event) and the pure algorithm (Scheduler).
// It handles mapping, runs the algorithm, and writes the result into WeekCache.
// Call regenerate(context:events:) whenever any event is added, edited, or deleted.

enum SchedulerService {

    // MARK: - Public API

    /// Runs the scheduling algorithm and persists the result as a WeekCache.
    /// Deletes any existing cache entry first so there is always exactly one.
    static func regenerate(context: ModelContext, events: [Event]) throws {
        let fixed = events.compactMap { toFixedEvent($0) }
        let flexible = events.compactMap { toFlexibleEvent($0) }

        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: flexible, startingFrom: todayAsDayOfWeek())

        // Replace only this week's cache — older weeks are kept for Insights history
        let currentStart = currentWeekStart()
        let existing = try context.fetch(FetchDescriptor<WeekCache>())
        existing
            .filter { Calendar.current.isDate($0.weekStartDate, equalTo: currentStart, toGranularity: .weekOfYear) }
            .forEach { context.delete($0) }

        let json = try encodePlacements(schedule.placedFlexibleEvents)
        let heavyDayValues = schedule.heavyDays.map { $0.rawValue }

        let cache = WeekCache(
            weekStartDate: currentWeekStart(),
            placementsJSON: json,
            balanceScore: schedule.balanceScore,
            heavyDayValues: heavyDayValues
        )
        context.insert(cache)

        // Trim history to 8 weeks so SwiftData doesn't accumulate unbounded records.
        // Insights only renders the last 8 weeks, so anything older has no UX value.
        let all = try context.fetch(FetchDescriptor<WeekCache>(sortBy: [SortDescriptor(\.weekStartDate, order: .reverse)]))
        if all.count > 8 {
            all.dropFirst(8).forEach { context.delete($0) }
        }
    }

    /// Reads the current cache and decodes it back into a WeekSchedule.
    /// Returns nil if the cache is empty or stale (caller should trigger regenerate).
    static func loadCachedSchedule(context: ModelContext, events: [Event]) throws -> WeekSchedule? {
        let caches = try context.fetch(FetchDescriptor<WeekCache>())
        guard let cache = caches.first else { return nil }

        // Stale if the cache is from a previous week
        guard Calendar.current.isDate(cache.weekStartDate, equalTo: currentWeekStart(), toGranularity: .weekOfYear) else {
            return nil
        }

        let placements = try decodePlacements(cache.placementsJSON, events: events)
        let fixed = events.compactMap { toFixedEvent($0) }
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

    // MARK: - Day query

    /// Returns all events scheduled on a given day — fixed events anchored there, plus
    /// flexible events the algorithm placed there. Used by HomeView to populate the day list.
    static func events(for day: DayOfWeek, cache: WeekCache, from events: [Event]) -> [Event] {
        let fixed = events.filter { $0.isFixed && $0.fixedDay == day }
        let placedIds = flexibleIds(for: day, in: cache.placementsJSON)
        let flexible = events.filter { !$0.isFixed && placedIds.contains($0.id) }
        return fixed + flexible
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

    // MARK: - Mapping: SwiftData Event → pure structs

    private static func toFixedEvent(_ event: Event) -> FixedEvent? {
        guard event.isFixed, let day = event.fixedDay else { return nil }
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
    private static func currentWeekStart() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2  // Monday
        return cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    // Calendar.weekday: 1=Sun 2=Mon 3=Tue 4=Wed 5=Thu 6=Fri 7=Sat
    // DayOfWeek.rawValue: 1=Mon … 7=Sun
    private static func todayAsDayOfWeek() -> DayOfWeek {
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
