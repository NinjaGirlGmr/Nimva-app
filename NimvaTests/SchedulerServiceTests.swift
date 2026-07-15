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

