import Testing
import Foundation
@testable import Nimva

@Suite("CandidateWindowService")
struct CandidateWindowServiceTests {

    // Builds a time-of-day Date on an arbitrary base day — defaults differ per call (`Date()`
    // evaluated fresh each time, a few milliseconds apart) specifically to catch any
    // regression toward comparing raw Dates instead of minuteOfDay: if the implementation
    // ever started comparing full Dates, events built on "different" underlying days here
    // would never be seen as adjacent/overlapping, and these tests would fail.
    private func time(_ hour: Int, _ minute: Int = 0, on baseDate: Date = Date()) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)!
    }

    private func fixedEvent(start: Date, end: Date, energyCost: Double = 0.8) -> Event {
        Event(name: "Other", isFixed: true, fixedDay: .monday, startTime: start, endTime: end, energyCost: energyCost)
    }

    // A deliberately different calendar day than `time`'s default, to exercise the
    // cross-date-component scenario described above.
    private var otherBaseDate: Date { Date().addingTimeInterval(10 * 24 * 3600) }

    @Test func emptyCandidatesReturnsNil() {
        #expect(CandidateWindowService.bestWindow(candidates: [], otherEventsOnDay: []) == nil)
    }

    @Test func singleCandidateWithNoOthersReturnsIt() {
        let candidate = CandidateWindowService.Window(start: time(8), end: time(8, 30))
        let result = CandidateWindowService.bestWindow(candidates: [candidate], otherEventsOnDay: [])
        #expect(result == candidate)
    }

    @Test func overlappingCandidateIsExcluded() {
        // 8:00–8:30 collides with an existing 8:15–9:00 class; 3:45–4:15 is clear.
        let overlapping = CandidateWindowService.Window(start: time(8), end: time(8, 30))
        let clear = CandidateWindowService.Window(start: time(15, 45), end: time(16, 15))
        let existing = fixedEvent(start: time(8, 15, on: otherBaseDate), end: time(9, on: otherBaseDate))

        let result = CandidateWindowService.bestWindow(candidates: [overlapping, clear], otherEventsOnDay: [existing])
        #expect(result == clear)
    }

    @Test func prefersMoreBreathingRoomFromADrainingNeighbor() {
        // A draining class runs 9:00–9:45. 8:00–8:30 butts right up against it (15 min gap);
        // 3:45–4:15 has hours of room. The latter should win even though neither overlaps.
        let tight = CandidateWindowService.Window(start: time(8), end: time(8, 30))
        let roomy = CandidateWindowService.Window(start: time(15, 45), end: time(16, 15))
        let drainingClass = fixedEvent(start: time(9, on: otherBaseDate), end: time(9, 45, on: otherBaseDate), energyCost: 0.9)

        let result = CandidateWindowService.bestWindow(candidates: [tight, roomy], otherEventsOnDay: [drainingClass])
        #expect(result == roomy)
    }

    @Test func nonDrainingNeighborsDoNotAffectTheScore() {
        // Both candidates sit tight against a neighbor, but neither neighbor is draining
        // (energyCost 0.3) — with no draining neighbor on either side, both candidates have
        // "unlimited room" and the result should be deterministic (first candidate, since
        // max(by:) doesn't replace on a tie), not accidentally penalized by a light event.
        let nearLightEventA = CandidateWindowService.Window(start: time(8), end: time(8, 30))
        let nearLightEventB = CandidateWindowService.Window(start: time(15, 45), end: time(16, 15))
        let lightNeighbor = fixedEvent(start: time(8, 30, on: otherBaseDate), end: time(9, on: otherBaseDate), energyCost: 0.3)

        let result = CandidateWindowService.bestWindow(candidates: [nearLightEventA, nearLightEventB], otherEventsOnDay: [lightNeighbor])
        #expect(result == nearLightEventA)
    }

    @Test func allCandidatesOverlappingFallsBackToFirst() {
        let allDayClass = fixedEvent(start: time(7, on: otherBaseDate), end: time(18, on: otherBaseDate))
        let a = CandidateWindowService.Window(start: time(8), end: time(8, 30))
        let b = CandidateWindowService.Window(start: time(15, 45), end: time(16, 15))

        let result = CandidateWindowService.bestWindow(candidates: [a, b], otherEventsOnDay: [allDayClass])
        #expect(result == a)
    }

    @Test func eventsWithoutStartOrEndTimeAreIgnoredAsNeighbors() {
        // A flexible event (no startTime/endTime) sitting in otherEventsOnDay shouldn't crash
        // or factor into the scoring at all.
        let flexible = Event(name: "Flexible", isFixed: false, energyCost: 0.9)
        let candidate = CandidateWindowService.Window(start: time(8), end: time(8, 30))
        let result = CandidateWindowService.bestWindow(candidates: [candidate], otherEventsOnDay: [flexible])
        #expect(result == candidate)
    }

    @Test func gapIsMeasuredFromTheTighterOfTheTwoSides() {
        // A candidate wedged between two draining events — 15 min before, 2 hours after.
        // Its score should be the tighter (15 min) side, not the looser one.
        let before = fixedEvent(start: time(7, on: otherBaseDate), end: time(7, 45, on: otherBaseDate))
        let after = fixedEvent(start: time(10, on: otherBaseDate), end: time(10, 45, on: otherBaseDate))
        let wedged = CandidateWindowService.Window(start: time(8), end: time(8, 30))
        // A second candidate with a consistent 20-minute gap on both sides — better than the
        // wedged option's 15-minute tight side.
        let roomierBothSides = CandidateWindowService.Window(start: time(8, 5), end: time(9, 40))

        let result = CandidateWindowService.bestWindow(
            candidates: [wedged, roomierBothSides],
            otherEventsOnDay: [before, after]
        )
        #expect(result == roomierBothSides)
    }
}
