import Testing
import Foundation
@testable import Nimva

@Suite("WeekAccessPolicy — maxVisibleOffset")
struct WeekAccessPolicyMaxOffsetTests {

    @Test(arguments: [DayOfWeek.monday, .tuesday, .wednesday])
    func freeTierBeforeThursdayCapsAtZero(day: DayOfWeek) {
        #expect(WeekAccessPolicy.maxVisibleOffset(today: day, isProEnabled: false) == 0)
    }

    @Test(arguments: [DayOfWeek.thursday, .friday, .saturday, .sunday])
    func freeTierFromThursdayAllowsOneWeekAhead(day: DayOfWeek) {
        #expect(WeekAccessPolicy.maxVisibleOffset(today: day, isProEnabled: false) == 1)
    }

    @Test(arguments: DayOfWeek.allCases)
    func proTierAlwaysAllowsThreeWeeksRegardlessOfDay(day: DayOfWeek) {
        #expect(WeekAccessPolicy.maxVisibleOffset(today: day, isProEnabled: true) == 3)
    }

    @Test func freeTierBoundaryIsExactlyWednesdayToThursday() {
        #expect(WeekAccessPolicy.maxVisibleOffset(today: .wednesday, isProEnabled: false) == 0)
        #expect(WeekAccessPolicy.maxVisibleOffset(today: .thursday, isProEnabled: false) == 1)
    }
}

@Suite("WeekAccessPolicy — weekLabel")
struct WeekAccessPolicyLabelTests {

    @Test func weekLabelForOffsetZeroIsThisWeek() {
        #expect(WeekAccessPolicy.weekLabel(offset: 0, weekStartDate: Date()) == "This week")
    }

    @Test func weekLabelForOffsetOneIsNextWeek() {
        #expect(WeekAccessPolicy.weekLabel(offset: 1, weekStartDate: Date()) == "Next week")
    }

    @Test func weekLabelForOffsetTwoOrThreeShowsFormattedDate() {
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 3
        let date = Calendar.current.date(from: components)!
        #expect(WeekAccessPolicy.weekLabel(offset: 2, weekStartDate: date) == "Week of Aug 3")
        #expect(WeekAccessPolicy.weekLabel(offset: 3, weekStartDate: date) == "Week of Aug 3")
    }
}
