import Testing
import SwiftData
import Foundation
@testable import Nimva

// MARK: - Helpers

// Builds the placements JSON that SchedulerService.events(for:cache:from:)
// and overflowCount(cache:totalFlexible:) expect to decode.
// Mirrors the private PlacementRecord format: [{eventId, dayRawValue}].
private func makePlacementsJSON(_ placements: [(UUID, DayOfWeek)]) -> String {
    let records = placements.map { id, day in
        ["eventId": id.uuidString, "dayRawValue": day.rawValue] as [String: Any]
    }
    let data = (try? JSONSerialization.data(withJSONObject: records)) ?? Data()
    return String(data: data, encoding: .utf8) ?? "[]"
}

private func makeCache(_ placements: [(UUID, DayOfWeek)] = []) -> WeekCache {
    WeekCache(
        weekStartDate: Date(),
        placementsJSON: makePlacementsJSON(placements),
        balanceScore: 0.5,
        heavyDayValues: []
    )
}

// MARK: - events(for:cache:from:)

@Suite("SchedulerService — events(for:cache:from:)")
@MainActor
struct SchedulerServiceDayQueryTests {

    @Test func fixedEventOnQueriedDayIsReturned() {
        let event = Event(name: "Lecture", isFixed: true, fixedDay: .tuesday)
        let result = SchedulerService.events(for: .tuesday, cache: makeCache(), from: [event])
        #expect(result.count == 1)
        #expect(result.first?.name == "Lecture")
    }

    @Test func fixedEventOnOtherDayIsNotReturned() {
        let event = Event(name: "Lecture", isFixed: true, fixedDay: .tuesday)
        let result = SchedulerService.events(for: .wednesday, cache: makeCache(), from: [event])
        #expect(result.isEmpty)
    }

    @Test func flexibleEventInPlacementsIsReturned() {
        let event = Event(name: "Gym", isFixed: false)
        let result = SchedulerService.events(
            for: .thursday,
            cache: makeCache([(event.id, .thursday)]),
            from: [event]
        )
        #expect(result.count == 1)
        #expect(result.first?.name == "Gym")
    }

    @Test func flexibleEventOnWrongDayIsNotReturned() {
        let event = Event(name: "Gym", isFixed: false)
        let result = SchedulerService.events(
            for: .monday,
            cache: makeCache([(event.id, .thursday)]),
            from: [event]
        )
        #expect(result.isEmpty)
    }

    @Test func fixedAndFlexibleReturnedForSameDay() {
        let fixed = Event(name: "Class", isFixed: true, fixedDay: .monday)
        let flex  = Event(name: "Study", isFixed: false)
        let other = Event(name: "Run",   isFixed: false)

        let cache = makeCache([(flex.id, .monday), (other.id, .friday)])
        let result = SchedulerService.events(for: .monday, cache: cache, from: [fixed, flex, other])

        #expect(result.count == 2)
        #expect(result.contains { $0.name == "Class" })
        #expect(result.contains { $0.name == "Study" })
    }

    @Test func emptyEventListReturnsEmpty() {
        let result = SchedulerService.events(for: .tuesday, cache: makeCache(), from: [])
        #expect(result.isEmpty)
    }

    @Test func malformedJSONStillReturnsFixedEvents() {
        let fixed = Event(name: "Class", isFixed: true, fixedDay: .monday)
        let cache = WeekCache(weekStartDate: Date(), placementsJSON: "not json", balanceScore: 0.5, heavyDayValues: [])
        let result = SchedulerService.events(for: .monday, cache: cache, from: [fixed])
        // Fixed events are returned regardless of JSON validity
        #expect(result.count == 1)
    }

    @Test func flexibleEventWithNilFixedDayIsNotReturnedAsFixed() {
        // A flexible event (isFixed: false, fixedDay: nil) must never appear in
        // the fixed list even if it happens to share a day with the query.
        let event = Event(name: "Study", isFixed: false, fixedDay: .monday)
        let result = SchedulerService.events(for: .monday, cache: makeCache(), from: [event])
        #expect(result.isEmpty)
    }
}

// MARK: - overflowCount(cache:totalFlexible:)

@Suite("SchedulerService — overflowCount")
@MainActor
struct SchedulerServiceOverflowTests {

    @Test func overflowCorrectWhenSomeUnplaced() {
        let cache = makeCache([(UUID(), .monday), (UUID(), .tuesday), (UUID(), .wednesday)])
        #expect(SchedulerService.overflowCount(cache: cache, totalFlexible: 5) == 2)
    }

    @Test func noOverflowWhenAllPlaced() {
        let cache = makeCache([(UUID(), .monday), (UUID(), .tuesday)])
        #expect(SchedulerService.overflowCount(cache: cache, totalFlexible: 2) == 0)
    }

    @Test func overflowNeverNegative() {
        // More placements than totalFlexible — clamp at 0, never return negative
        let cache = makeCache([(UUID(), .monday), (UUID(), .tuesday), (UUID(), .wednesday)])
        #expect(SchedulerService.overflowCount(cache: cache, totalFlexible: 2) == 0)
    }

    @Test func emptyPlacementsAllOverflow() {
        let cache = makeCache([])
        #expect(SchedulerService.overflowCount(cache: cache, totalFlexible: 3) == 3)
    }

    @Test func emptyJSONArrayAllOverflow() {
        let cache = WeekCache(weekStartDate: Date(), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        #expect(SchedulerService.overflowCount(cache: cache, totalFlexible: 4) == 4)
    }

    @Test func malformedJSONReturnsZeroNotTotal() {
        // Guard path — can't decode → returns 0, not totalFlexible
        let cache = WeekCache(weekStartDate: Date(), placementsJSON: "{bad}", balanceScore: 0, heavyDayValues: [])
        #expect(SchedulerService.overflowCount(cache: cache, totalFlexible: 5) == 0)
    }

    @Test func zeroFlexibleZeroOverflow() {
        let cache = makeCache([(UUID(), .monday)])
        #expect(SchedulerService.overflowCount(cache: cache, totalFlexible: 0) == 0)
    }
}

// MARK: - Completion state (#83)

private func makeIdsJSON(_ ids: [UUID]) -> String {
    let data = (try? JSONEncoder().encode(ids.map { $0.uuidString })) ?? Data()
    return String(data: data, encoding: .utf8) ?? "[]"
}

@Suite("SchedulerService — completion state")
@MainActor
struct CompletionStateTests {

    private func makeCache(completed: [UUID] = [], inProgress: [UUID] = []) -> WeekCache {
        let cache = WeekCache(weekStartDate: Date(), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        cache.completedEventIdsJSON = makeIdsJSON(completed)
        cache.inProgressEventIdsJSON = makeIdsJSON(inProgress)
        return cache
    }

    @Test func defaultsToNotStarted() {
        let id = UUID()
        let cache = makeCache()
        #expect(SchedulerService.completionState(for: id, cache: cache) == .notStarted)
    }

    @Test func reflectsCompletedSet() {
        let id = UUID()
        let cache = makeCache(completed: [id])
        #expect(SchedulerService.completionState(for: id, cache: cache) == .completed)
    }

    @Test func reflectsInProgressSet() {
        let id = UUID()
        let cache = makeCache(inProgress: [id])
        #expect(SchedulerService.completionState(for: id, cache: cache) == .inProgress)
    }

    @Test func malformedJSONDefaultsToNotStarted() {
        let id = UUID()
        let cache = WeekCache(weekStartDate: Date(), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        cache.completedEventIdsJSON = "{bad}"
        cache.inProgressEventIdsJSON = "{bad}"
        #expect(SchedulerService.completionState(for: id, cache: cache) == .notStarted)
    }

    @Test func notStartedCyclesToInProgress() {
        let id = UUID()
        let result = SchedulerService.cycledCompletionJSON(for: id, completedJSON: "[]", inProgressJSON: "[]")
        #expect(SchedulerService.completionState(
            for: id,
            cache: makeCacheFromJSON(completed: result.completed, inProgress: result.inProgress)
        ) == .inProgress)
    }

    @Test func inProgressCyclesToCompleted() {
        let id = UUID()
        let result = SchedulerService.cycledCompletionJSON(
            for: id, completedJSON: "[]", inProgressJSON: makeIdsJSON([id])
        )
        #expect(SchedulerService.completionState(
            for: id,
            cache: makeCacheFromJSON(completed: result.completed, inProgress: result.inProgress)
        ) == .completed)
    }

    @Test func completedCyclesBackToNotStarted() {
        let id = UUID()
        let result = SchedulerService.cycledCompletionJSON(
            for: id, completedJSON: makeIdsJSON([id]), inProgressJSON: "[]"
        )
        #expect(SchedulerService.completionState(
            for: id,
            cache: makeCacheFromJSON(completed: result.completed, inProgress: result.inProgress)
        ) == .notStarted)
    }

    @Test func cyclingOneEventDoesNotAffectAnother() {
        let target = UUID()
        let other = UUID()
        let result = SchedulerService.cycledCompletionJSON(
            for: target, completedJSON: "[]", inProgressJSON: makeIdsJSON([other])
        )
        let cache = makeCacheFromJSON(completed: result.completed, inProgress: result.inProgress)
        #expect(SchedulerService.completionState(for: target, cache: cache) == .inProgress)
        #expect(SchedulerService.completionState(for: other, cache: cache) == .inProgress)
    }

    private func makeCacheFromJSON(completed: String, inProgress: String) -> WeekCache {
        let cache = WeekCache(weekStartDate: Date(), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        cache.completedEventIdsJSON = completed
        cache.inProgressEventIdsJSON = inProgress
        return cache
    }
}

@Suite("SchedulerService — isCompletionPremature")
@MainActor
struct IsCompletionPrematureTests {

    @Test func futureDayIsAlwaysPremature() {
        let event = Event(name: "Test", isFixed: false, preferredWindow: .any, energyCost: 0.5)
        #expect(SchedulerService.isCompletionPremature(event: event, selectedDay: .friday, today: .monday))
    }

    @Test func pastDayIsNeverPremature() {
        let event = Event(name: "Test", isFixed: false, preferredWindow: .any, energyCost: 0.5)
        #expect(!SchedulerService.isCompletionPremature(event: event, selectedDay: .monday, today: .friday))
    }

    @Test func flexibleEventTodayIsNeverPremature() {
        // Flexible events have no specific hour, so "today" is as fine-grained as it gets.
        let event = Event(name: "Test", isFixed: false, preferredWindow: .any, energyCost: 0.5)
        #expect(!SchedulerService.isCompletionPremature(event: event, selectedDay: .wednesday, today: .wednesday))
    }

    // Uses explicit hour/minute construction rather than now.addingTimeInterval(±3600) —
    // a relative offset from a live Date() can silently wrap across midnight depending on
    // what second the test happens to run (caught this for real: run at 00:24 AM, "-1 hour"
    // landed at 23:24 the day before, which broke the equivalent hand-written test below
    // before this fix). Deterministic construction avoids that flakiness entirely.
    @Test func fixedEventTodayWithFutureStartTimeIsPremature() {
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let future = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: Date())!
        let event = Event(name: "Test", isFixed: true, fixedDay: .wednesday, startTime: future, endTime: future, energyCost: 0.5)
        #expect(SchedulerService.isCompletionPremature(event: event, selectedDay: .wednesday, today: .wednesday, now: now))
    }

    @Test func fixedEventTodayWithPastStartTimeIsNotPremature() {
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let past = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
        let event = Event(name: "Test", isFixed: true, fixedDay: .wednesday, startTime: past, endTime: now, energyCost: 0.5)
        #expect(!SchedulerService.isCompletionPremature(event: event, selectedDay: .wednesday, today: .wednesday, now: now))
    }

    // Regression: a real fixed event's startTime carries whatever date it happened to be
    // created on — weeks or months in the past for anything set up once and left recurring.
    // Only the time-of-day is meaningful. This mirrors that: startTime's DATE is long past,
    // but its time-of-day (8 PM) is still later than "now" (noon), so it should still read
    // as premature. A full-Date comparison would get this wrong.
    @Test func fixedEventWithStaleDateButFutureTimeOfDayIsPremature() {
        let calendar = Calendar.current
        let staleCreationDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        let staleStart = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: staleCreationDate)!
        let now = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let event = Event(name: "Training Camp", isFixed: true, fixedDay: .wednesday, startTime: staleStart, endTime: staleStart, energyCost: 0.5)
        #expect(SchedulerService.isCompletionPremature(event: event, selectedDay: .wednesday, today: .wednesday, now: now))
    }

    @Test func fixedEventWithStaleDateButPastTimeOfDayIsNotPremature() {
        let calendar = Calendar.current
        let staleCreationDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        let staleStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: staleCreationDate)!
        let now = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        let event = Event(name: "Morning Class", isFixed: true, fixedDay: .wednesday, startTime: staleStart, endTime: staleStart, energyCost: 0.5)
        #expect(!SchedulerService.isCompletionPremature(event: event, selectedDay: .wednesday, today: .wednesday, now: now))
    }

    @Test func fixedEventAtExactSameMinuteIsNotPremature() {
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let event = Event(name: "Test", isFixed: true, fixedDay: .wednesday, startTime: now, endTime: now, energyCost: 0.5)
        #expect(!SchedulerService.isCompletionPremature(event: event, selectedDay: .wednesday, today: .wednesday, now: now))
    }

    @Test func fixedEventWithNoStartTimeIsNotPremature() {
        // Defensive: a fixed event should always have a startTime in practice, but guard
        // against a nil value being treated as "always premature."
        let event = Event(name: "Test", isFixed: true, fixedDay: .wednesday, energyCost: 0.5)
        #expect(!SchedulerService.isCompletionPremature(event: event, selectedDay: .wednesday, today: .wednesday))
    }
}

// MARK: - Multi-week regenerate/load (#13 — rolling calendar)

@MainActor
private func makeInMemoryContext() throws -> ModelContext {
    let schema = Schema([Event.self, WeekCache.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return ModelContext(try ModelContainer(for: schema, configurations: [config]))
}

// MARK: - weekStart() locale awareness

@Suite("SchedulerService — weekStart locale awareness")
struct WeekStartLocaleTests {

    // Regression: weekStart() used to hardcode Monday as the week boundary regardless of
    // device locale, so a US user's Sunday was still classified as the tail end of last
    // week instead of the start of a new one. weekBoundaryCal now derives firstWeekday from
    // Calendar.current, matching DayOfWeek.orderedForLocale's own convention — this asserts
    // that behavior dynamically against whatever locale the test happens to run under,
    // rather than hardcoding an assumption about which one that is.
    @Test func weekStartMatchesDeviceLocaleFirstWeekday() {
        let start = SchedulerService.weekStart()
        // Calendar's .weekday component is always 1=Sunday...7=Saturday, independent of
        // firstWeekday — a stable way to check which actual day weekStart() landed on.
        let weekday = Calendar.current.component(.weekday, from: start)
        if Calendar.current.firstWeekday == 1 {
            #expect(weekday == 1)  // Sunday-first locale (e.g. US) — week starts Sunday
        } else {
            #expect(weekday == 2)  // Monday-first locale (e.g. most of Europe/ISO)
        }
    }

    @Test func weekBoundaryCalFirstWeekdayMatchesDeviceLocale() {
        #expect(SchedulerService.weekBoundaryCal.firstWeekday == Calendar.current.firstWeekday)
    }
}

// MARK: - currentWeekCache(from:)

@Suite("SchedulerService — currentWeekCache")
struct CurrentWeekCacheTests {

    @Test func findsCurrentWeekCacheWhenItIsTheOnlyOne() {
        let cache = WeekCache(weekStartDate: SchedulerService.weekStart(), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        #expect(SchedulerService.currentWeekCache(from: [cache]) === cache)
    }

    // Regression test for a bug where Home treated a genuinely-built current week as
    // "not built yet" whenever a newer future-week cache (from testing the rolling
    // calendar) existed — the lookup assumed the newest row was the one wanted instead
    // of searching for the actual match.
    @Test func findsCurrentWeekCacheEvenWhenANewerFutureCacheExists() {
        let current = WeekCache(weekStartDate: SchedulerService.weekStart(), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        let future = WeekCache(weekStartDate: SchedulerService.weekStart(offsetWeeks: 2), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        // Newest-first, matching the @Query sort order HomeView actually uses.
        let result = SchedulerService.currentWeekCache(from: [future, current])
        #expect(result === current)
    }

    @Test func returnsNilWhenOnlyFutureCachesExist() {
        let future = WeekCache(weekStartDate: SchedulerService.weekStart(offsetWeeks: 1), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        #expect(SchedulerService.currentWeekCache(from: [future]) == nil)
    }

    @Test func returnsNilForEmptyList() {
        #expect(SchedulerService.currentWeekCache(from: []) == nil)
    }
}

@Suite("SchedulerService — multi-week regenerate/load")
@MainActor
struct MultiWeekSchedulerServiceTests {

    @Test func regenerateForDifferentOffsetsCreatesSeparateCaches() throws {
        let context = try makeInMemoryContext()
        let events = [Event(name: "Gym", isFixed: false)]

        try SchedulerService.regenerate(context: context, events: events, weekOffset: 0)
        try SchedulerService.regenerate(context: context, events: events, weekOffset: 1)
        try SchedulerService.regenerate(context: context, events: events, weekOffset: 2)

        let all = try context.fetch(FetchDescriptor<WeekCache>(sortBy: [SortDescriptor(\.weekStartDate)]))
        #expect(all.count == 3)
        let sevenDays: TimeInterval = 7 * 24 * 3600
        #expect(abs(all[1].weekStartDate.timeIntervalSince(all[0].weekStartDate) - sevenDays) < 60)
        #expect(abs(all[2].weekStartDate.timeIntervalSince(all[1].weekStartDate) - sevenDays) < 60)
    }

    @Test func regeneratingOneOffsetDoesNotMutateAnotherOffsetsCache() throws {
        let context = try makeInMemoryContext()
        let events = [Event(name: "Gym", isFixed: false, energyCost: 0.4)]

        try SchedulerService.regenerate(context: context, events: events, weekOffset: 0)
        let beforeAll = try context.fetch(FetchDescriptor<WeekCache>())
        let thisWeekBefore = beforeAll.first { SchedulerService.weekBoundaryCal.isDate($0.weekStartDate, equalTo: SchedulerService.weekStart(offsetWeeks: 0), toGranularity: .weekOfYear) }
        let jsonBefore = thisWeekBefore?.placementsJSON

        // Rebuild next week — this week's cache must be untouched (regression test for
        // the currentStart -> targetStart fix).
        try SchedulerService.regenerate(context: context, events: events, weekOffset: 1)

        let afterAll = try context.fetch(FetchDescriptor<WeekCache>())
        let thisWeekAfter = afterAll.first { SchedulerService.weekBoundaryCal.isDate($0.weekStartDate, equalTo: SchedulerService.weekStart(offsetWeeks: 0), toGranularity: .weekOfYear) }
        #expect(afterAll.count == 2)
        #expect(thisWeekAfter?.placementsJSON == jsonBefore)
    }

    @Test func loadCachedScheduleFindsMatchingOffsetEvenWhenANewerOffsetCacheExists() throws {
        let context = try makeInMemoryContext()
        let events = [Event(name: "Gym", isFixed: false)]

        try SchedulerService.regenerate(context: context, events: events, weekOffset: 0)
        try SchedulerService.regenerate(context: context, events: events, weekOffset: 2)   // offset 1 deliberately skipped

        let offset1 = try SchedulerService.loadCachedSchedule(context: context, events: events, weekOffset: 1)
        let offset2 = try SchedulerService.loadCachedSchedule(context: context, events: events, weekOffset: 2)
        #expect(offset1 == nil)
        #expect(offset2 != nil)
    }

    @Test func loadCachedScheduleReturnsNilForOffsetWithNoCache() throws {
        let context = try makeInMemoryContext()
        let events = [Event(name: "Gym", isFixed: false)]
        try SchedulerService.regenerate(context: context, events: events, weekOffset: 0)

        let result = try SchedulerService.loadCachedSchedule(context: context, events: events, weekOffset: 1)
        #expect(result == nil)
    }

    // Future weeks have no "past days" yet, so `today` is forced to .monday inside regenerate,
    // which naturally empties pastRecords/idsInPast regardless of preservePastPlacements. This
    // can only be asserted deterministically for the future-week half — todayAsDayOfWeek() has
    // no injection point for a fake "today," so the current-week half of this behavior remains
    // untested here (pre-existing limitation, not something this feature needs to fix).
    @Test func futureWeekRegenerateIgnoresPreservePastPlacementsFlag() throws {
        let context = try makeInMemoryContext()
        let events = [Event(name: "Gym", isFixed: false, energyCost: 0.4)]

        try SchedulerService.regenerate(context: context, events: events, preservePastPlacements: true, weekOffset: 1)
        let all = try context.fetch(FetchDescriptor<WeekCache>())
        #expect(all.count == 1)
        // No prior cache existed for this future week, so nothing could have been "preserved" —
        // the placement is freshly computed regardless of the flag.
        #expect(all.first?.placementsJSON.contains(events[0].id.uuidString) == true)
    }

    @Test func trimKeepsUpToEightHistoryCachesIndependentOfFutureCaches() throws {
        let context = try makeInMemoryContext()
        let events = [Event(name: "Gym", isFixed: false)]

        // Seed 9 past-dated caches directly (bypassing regenerate, which would trim as it goes).
        let sevenDays: TimeInterval = 7 * 24 * 3600
        for i in 1...9 {
            let past = SchedulerService.weekStart().addingTimeInterval(-Double(i) * sevenDays)
            context.insert(WeekCache(weekStartDate: past, placementsJSON: "[]", balanceScore: 0, heavyDayValues: []))
        }

        // Populate the future bucket, then trigger a trim via one more regenerate call.
        try SchedulerService.regenerate(context: context, events: events, weekOffset: 1)
        try SchedulerService.regenerate(context: context, events: events, weekOffset: 2)
        try SchedulerService.regenerate(context: context, events: events, weekOffset: 0)

        let all = try context.fetch(FetchDescriptor<WeekCache>())
        let todayStart = SchedulerService.weekStart()
        let history = all.filter { $0.weekStartDate <= todayStart }
        let future = all.filter { $0.weekStartDate > todayStart }
        #expect(history.count == 8)
        #expect(future.count == 2)
    }

    @Test func trimCapsFuturePoolIfMoreThanThreeFutureCachesExistSomehow() throws {
        let context = try makeInMemoryContext()
        let events = [Event(name: "Gym", isFixed: false)]

        // Seed 5 future-dated caches directly, simulating a bug that bypassed the UI's +3 gate.
        let sevenDays: TimeInterval = 7 * 24 * 3600
        for i in 1...5 {
            let future = SchedulerService.weekStart().addingTimeInterval(Double(i) * sevenDays)
            context.insert(WeekCache(weekStartDate: future, placementsJSON: "[]", balanceScore: 0, heavyDayValues: []))
        }

        try SchedulerService.regenerate(context: context, events: events, weekOffset: 0)

        let all = try context.fetch(FetchDescriptor<WeekCache>())
        let todayStart = SchedulerService.weekStart()
        let future = all.filter { $0.weekStartDate > todayStart }.sorted { $0.weekStartDate < $1.weekStartDate }
        #expect(future.count == 3)
        // Must be the 3 NEAREST future weeks (+1, +2, +3), not the 3 furthest — regression
        // test for a real ordering bug where dropFirst(3) on furthest-first-sorted data
        // deleted the nearest weeks and kept the furthest ones instead.
        let expectedNearest = (1...3).map { SchedulerService.weekStart().addingTimeInterval(Double($0) * sevenDays) }
        for (actual, expected) in zip(future, expectedNearest) {
            #expect(abs(actual.weekStartDate.timeIntervalSince(expected)) < 60)
        }
    }

    // Regression test for the defensive floor added to regenerate/loadCachedSchedule —
    // a negative offset must never be allowed to target (and silently overwrite) a real
    // past week's cache with a fresh recompute.
    @Test func negativeWeekOffsetIsClampedToZeroNotAPastWeek() throws {
        let context = try makeInMemoryContext()
        let events = [Event(name: "Gym", isFixed: false)]

        try SchedulerService.regenerate(context: context, events: events, weekOffset: -3)

        let all = try context.fetch(FetchDescriptor<WeekCache>())
        #expect(all.count == 1)
        #expect(SchedulerService.weekBoundaryCal.isDate(
            all.first!.weekStartDate, equalTo: SchedulerService.weekStart(), toGranularity: .weekOfYear
        ))
    }

    // Regression test for multi-week calendar import: a date-specific fixed event
    // (Event.specificDate set) must only appear in the week containing that date,
    // never in an adjacent week's build.
    @Test func dateSpecificFixedEventOnlyAppearsInItsOwnWeek() throws {
        let context = try makeInMemoryContext()
        let nextWeekMonday = SchedulerService.weekStart(offsetWeeks: 1)
        let oneOffEvent = Event(
            name: "Dentist", isFixed: true, fixedDay: .monday,
            startTime: nextWeekMonday, endTime: nextWeekMonday.addingTimeInterval(3600),
            specificDate: nextWeekMonday
        )

        let thisWeekResult = try SchedulerService.regenerate(context: context, events: [oneOffEvent], weekOffset: 0)
        #expect(!thisWeekResult.fixedEvents.contains { $0.name == "Dentist" })

        let nextWeekResult = try SchedulerService.regenerate(context: context, events: [oneOffEvent], weekOffset: 1)
        #expect(nextWeekResult.fixedEvents.contains { $0.name == "Dentist" })
    }

    // Mirror of the fixed-event test above, for flexible events — a "this week only"
    // flexible event (Event.specificDate set) must only ever be a placement candidate
    // for the week containing that date, not an adjacent one.
    @Test func dateSpecificFlexibleEventOnlyAppearsInItsOwnWeek() throws {
        let context = try makeInMemoryContext()
        let nextWeekMonday = SchedulerService.weekStart(offsetWeeks: 1)
        let oneOffFlex = Event(name: "Study for chem test", isFixed: false, specificDate: nextWeekMonday)

        let thisWeekResult = try SchedulerService.regenerate(context: context, events: [oneOffFlex], weekOffset: 0)
        #expect(!thisWeekResult.placedFlexibleEvents.contains { $0.event.name == "Study for chem test" })

        let nextWeekResult = try SchedulerService.regenerate(context: context, events: [oneOffFlex], weekOffset: 1)
        #expect(nextWeekResult.placedFlexibleEvents.contains { $0.event.name == "Study for chem test" })
    }
}

// MARK: - hasRecurringPattern

@Suite("SchedulerService — hasRecurringPattern")
struct HasRecurringPatternTests {

    private func oneOffFlex(name: String, weeksAgo: Int) -> Event {
        Event(name: name, isFixed: false, specificDate: SchedulerService.weekStart(offsetWeeks: -weeksAgo))
    }

    @Test func threeConsecutiveWeeksMatches() {
        let events = [
            oneOffFlex(name: "Study session", weeksAgo: 0),
            oneOffFlex(name: "Study session", weeksAgo: 1),
            oneOffFlex(name: "Study session", weeksAgo: 2),
        ]
        #expect(SchedulerService.hasRecurringPattern(name: "Study session", events: events))
    }

    @Test func onlyTwoConsecutiveWeeksDoesNotMatch() {
        let events = [
            oneOffFlex(name: "Study session", weeksAgo: 0),
            oneOffFlex(name: "Study session", weeksAgo: 1),
        ]
        #expect(!SchedulerService.hasRecurringPattern(name: "Study session", events: events))
    }

    @Test func threeWeeksWithAGapDoesNotMatch() {
        // Missing week -1 — not consecutive, even though 3 total occurrences exist.
        let events = [
            oneOffFlex(name: "Study session", weeksAgo: 0),
            oneOffFlex(name: "Study session", weeksAgo: 2),
            oneOffFlex(name: "Study session", weeksAgo: 3),
        ]
        #expect(!SchedulerService.hasRecurringPattern(name: "Study session", events: events))
    }

    @Test func nameMatchIsCaseAndWhitespaceInsensitive() {
        let events = [
            oneOffFlex(name: "  STUDY session ", weeksAgo: 0),
            oneOffFlex(name: "study SESSION", weeksAgo: 1),
            oneOffFlex(name: "Study Session", weeksAgo: 2),
        ]
        #expect(SchedulerService.hasRecurringPattern(name: "study session", events: events))
    }

    @Test func unrelatedNamesDoNotMatch() {
        let events = [
            oneOffFlex(name: "Gym", weeksAgo: 0),
            oneOffFlex(name: "Reading", weeksAgo: 1),
            oneOffFlex(name: "Cooking", weeksAgo: 2),
        ]
        #expect(!SchedulerService.hasRecurringPattern(name: "Study session", events: events))
    }

    @Test func fixedEventsWithMatchingNameDoNotCount() {
        let events = [
            Event(name: "Study session", isFixed: true, fixedDay: .monday, specificDate: SchedulerService.weekStart(offsetWeeks: 0)),
            Event(name: "Study session", isFixed: true, fixedDay: .monday, specificDate: SchedulerService.weekStart(offsetWeeks: -1)),
            Event(name: "Study session", isFixed: true, fixedDay: .monday, specificDate: SchedulerService.weekStart(offsetWeeks: -2)),
        ]
        #expect(!SchedulerService.hasRecurringPattern(name: "Study session", events: events))
    }

    @Test func alreadyRecurringEventDoesNotCountTowardThePattern() {
        // specificDate == nil means "already every week" — it shouldn't feed into
        // detecting a *new* one-off pattern (there's nothing to promote).
        let events = [
            Event(name: "Study session", isFixed: false, specificDate: nil)
        ]
        #expect(!SchedulerService.hasRecurringPattern(name: "Study session", events: events))
    }

    @Test func customThresholdIsRespected() {
        let events = [
            oneOffFlex(name: "Study session", weeksAgo: 0),
            oneOffFlex(name: "Study session", weeksAgo: 1),
        ]
        #expect(SchedulerService.hasRecurringPattern(name: "Study session", events: events, consecutiveWeeks: 2))
    }
}

// MARK: - isEventVisible (multi-week calendar import)

@Suite("SchedulerService — isEventVisible")
struct IsEventVisibleTests {

    @Test func recurringEventWithNoSpecificDateIsAlwaysVisible() {
        let event = Event(name: "Math Class", isFixed: true, fixedDay: .monday)
        #expect(SchedulerService.isEventVisible(event, inWeekStarting: SchedulerService.weekStart()))
        #expect(SchedulerService.isEventVisible(event, inWeekStarting: SchedulerService.weekStart(offsetWeeks: 2)))
    }

    @Test func dateSpecificEventVisibleOnlyInMatchingWeek() {
        let targetWeek = SchedulerService.weekStart(offsetWeeks: 1)
        let event = Event(name: "Dentist", isFixed: true, fixedDay: .monday, specificDate: targetWeek)
        #expect(SchedulerService.isEventVisible(event, inWeekStarting: targetWeek))
        #expect(!SchedulerService.isEventVisible(event, inWeekStarting: SchedulerService.weekStart()))
        #expect(!SchedulerService.isEventVisible(event, inWeekStarting: SchedulerService.weekStart(offsetWeeks: 2)))
    }
}

// MARK: - isLightWeek

@Suite("SchedulerService — isLightWeek")
struct LightWeekTests {

    @Test func emptyEventListIsNotLightWeek() {
        // An empty list means onboarding/first-run, not a light week — handled separately.
        #expect(SchedulerService.isLightWeek(events: []) == false)
    }

    @Test func singleLowCostEventIsLightWeek() {
        let event = Event(name: "Coffee chat", isFixed: true, fixedDay: .tuesday, energyCost: 0.3)
        #expect(SchedulerService.isLightWeek(events: [event]) == true)
    }

    @Test func totalCostBelowThresholdIsLight() {
        // Three events at 0.5 cost each = 1.5 total, below Scheduler.heavyDayThreshold (2.0)
        let events = (0..<3).map { _ in Event(name: "Event", isFixed: false, energyCost: 0.5) }
        #expect(SchedulerService.isLightWeek(events: events) == true)
    }

    @Test func totalCostAtThresholdIsNotLight() {
        // Exactly at threshold (2.0) — not a light week
        let events = (0..<4).map { _ in Event(name: "Event", isFixed: false, energyCost: 0.5) }
        #expect(SchedulerService.isLightWeek(events: events) == false)
    }

    @Test func totalCostAboveThresholdIsNotLight() {
        // Four events at 0.8 each = 3.2, well above threshold
        let events = (0..<4).map { _ in Event(name: "Event", isFixed: false, energyCost: 0.8) }
        #expect(SchedulerService.isLightWeek(events: events) == false)
    }

    @Test func mixedCostsBelowThresholdIsLight() {
        let e1 = Event(name: "Low", isFixed: true, fixedDay: .monday, energyCost: 0.2)
        let e2 = Event(name: "Medium", isFixed: false, energyCost: 0.5)
        let e3 = Event(name: "Low2", isFixed: true, fixedDay: .friday, energyCost: 0.3)
        // Total: 1.0 < 2.0
        #expect(SchedulerService.isLightWeek(events: [e1, e2, e3]) == true)
    }
}

// MARK: - Recovery week (WeekCache fields)

@Suite("WeekCache — Recovery week fields")
struct RecoveryWeekCacheTests {

    private func makeRecoveryCache(wasRecovery: Bool, checkInRaw: Int?) -> WeekCache {
        let cache = WeekCache(weekStartDate: Date(), placementsJSON: "[]", balanceScore: 0.5, heavyDayValues: [])
        cache.wasRecoveryWeek = wasRecovery
        cache.recoveryCheckInRaw = checkInRaw
        return cache
    }

    @Test func defaultWeekCacheIsNotRecovery() {
        let cache = WeekCache(weekStartDate: Date(), placementsJSON: "[]", balanceScore: 0.5, heavyDayValues: [])
        #expect(cache.wasRecoveryWeek == false)
        #expect(cache.recoveryCheckInRaw == nil)
    }

    @Test func flaggedRecoveryCacheReflectsTrue() {
        let cache = makeRecoveryCache(wasRecovery: true, checkInRaw: nil)
        #expect(cache.wasRecoveryWeek == true)
        #expect(cache.recoveryCheckInRaw == nil)
    }

    @Test func recoveryCheckInRawStoredCorrectly() {
        let yes = makeRecoveryCache(wasRecovery: true, checkInRaw: 1)
        let somewhat = makeRecoveryCache(wasRecovery: true, checkInRaw: 2)
        let no = makeRecoveryCache(wasRecovery: true, checkInRaw: 3)
        #expect(yes.recoveryCheckInRaw == 1)
        #expect(somewhat.recoveryCheckInRaw == 2)
        #expect(no.recoveryCheckInRaw == 3)
    }

    @Test func nonRecoveryWeekNeverGetsCheckInRaw() {
        // wasRecoveryWeek false → recoveryCheckInRaw should stay nil (not persisted by check-in flow)
        let cache = makeRecoveryCache(wasRecovery: false, checkInRaw: nil)
        #expect(cache.recoveryCheckInRaw == nil)
    }

    @Test func recoveryWeekDetectedFromIsLightWeek() {
        // Mirrors what SchedulerService.regenerate() does when building the cache
        let lightEvents = [Event(name: "Easy", isFixed: false, energyCost: 0.3)]
        let heavyEvents = (0..<4).map { _ in Event(name: "Hard", isFixed: false, energyCost: 0.8) }
        #expect(SchedulerService.isLightWeek(events: lightEvents) == true)
        #expect(SchedulerService.isLightWeek(events: heavyEvents) == false)
    }
}

