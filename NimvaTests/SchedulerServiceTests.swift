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

// MARK: - detectUserType

@Suite("SchedulerService — detectUserType")
@MainActor
struct SchedulerServiceUserTypeTests {

    private func events(fixed: Int, flexible: Int) -> [Event] {
        let f = (0..<fixed).map   { Event(name: "Fixed \($0)",    isFixed: true) }
        let x = (0..<flexible).map { Event(name: "Flexible \($0)", isFixed: false) }
        return f + x
    }

    @Test func fewerThanFourEventsDefaultsToOptimizer() {
        #expect(SchedulerService.detectUserType(events: []) == .optimizer)
        #expect(SchedulerService.detectUserType(events: events(fixed: 3, flexible: 0)) == .optimizer)
    }

    @Test func allFixedIsOverloadedFixed() {
        #expect(SchedulerService.detectUserType(events: events(fixed: 4, flexible: 0)) == .overloadedFixed)
    }

    @Test func ninetyPercentFixedIsOverloadedFixed() {
        // 9 fixed, 1 flex = 90% — exactly at boundary
        #expect(SchedulerService.detectUserType(events: events(fixed: 9, flexible: 1)) == .overloadedFixed)
    }

    @Test func eightyPercentFixedIsPatternLearner() {
        // 4 fixed, 1 flex = 80%
        #expect(SchedulerService.detectUserType(events: events(fixed: 4, flexible: 1)) == .patternLearner)
    }

    @Test func sixtyPercentFixedIsPatternLearner() {
        // 6 fixed, 4 flex = 60% — exactly at boundary
        #expect(SchedulerService.detectUserType(events: events(fixed: 6, flexible: 4)) == .patternLearner)
    }

    @Test func fiftyPercentFixedIsOptimizer() {
        #expect(SchedulerService.detectUserType(events: events(fixed: 5, flexible: 5)) == .optimizer)
    }

    @Test func allFlexibleIsOptimizer() {
        #expect(SchedulerService.detectUserType(events: events(fixed: 0, flexible: 10)) == .optimizer)
    }
}
