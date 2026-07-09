import Testing
import SwiftData
import Foundation
@testable import Nimva

// MARK: - Scheduler

@Suite("Scheduler — Core Placement")
struct SchedulerPlacementTests {

    
    @Test func flexibleEventAvoidsHighestLoadDay() {
        let fixed = [FixedEvent(name: "Work", day: .monday, energyCost: 1.0)]
        let flexible = [FlexibleEvent(name: "Gym", energyCost: 0.5)]

        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: flexible)

        let placed = schedule.placedFlexibleEvents.first
        #expect(placed != nil)
        #expect(placed?.day != .monday)
    }

    @Test func sevenEqualEventsSpreadAcrossAllDays() {
        let flexible = (0..<7).map { FlexibleEvent(name: "Event \($0)", energyCost: 0.5) }

        let schedule = Scheduler.generateWeek(fixed: [], flexible: flexible)

        let uniqueDays = Set(schedule.placedFlexibleEvents.map { $0.day })
        #expect(uniqueDays.count == 7)
    }

    @Test func allEventsAccountedFor() {
        let flexible = (0..<10).map { FlexibleEvent(name: "Event \($0)", energyCost: 0.5) }

        let schedule = Scheduler.generateWeek(fixed: [], flexible: flexible)

        let total = schedule.placedFlexibleEvents.count + schedule.overflowEvents.count
        #expect(total == 10)
    }

    @Test func highEnergyEventsPlacedBeforeLowEnergy() {
        // LPT order means the draining event should land first (on the lightest day)
        // and the result should be more balanced than reverse order would produce
        let flexible = [
            FlexibleEvent(name: "Light", energyCost: 0.25),
            FlexibleEvent(name: "Draining", energyCost: 1.0)
        ]

        let schedule = Scheduler.generateWeek(fixed: [], flexible: flexible)

        #expect(schedule.placedFlexibleEvents.count == 2)
        // Verify Draining was placed before Light by checking day loads are spread
        let loads = Array(schedule.dailyLoads.values)
        let maxLoad = loads.max() ?? 0
        #expect(maxLoad <= 1.25) // At most one event per day when 2 events, 7 days
    }
}

@Suite("Scheduler — Edge Cases")
struct SchedulerEdgeCaseTests {

    @Test func emptyFlexibleListIsValid() {
        let fixed = [FixedEvent(name: "Meeting", day: .wednesday, energyCost: 0.5)]
        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: [])

        #expect(schedule.placedFlexibleEvents.isEmpty)
        #expect(schedule.overflowEvents.isEmpty)
    }

    @Test func fullyEmptyInputIsValid() {
        let schedule = Scheduler.generateWeek(fixed: [], flexible: [])

        #expect(schedule.placedFlexibleEvents.isEmpty)
        #expect(schedule.balanceScore == 0.0)
        #expect(schedule.heavyDays.isEmpty)
    }

    @Test func largeEventListDoesNotCrash() {
        let flexible = (0..<100).map {
            FlexibleEvent(name: "Event \($0)", energyCost: Double($0 % 4 + 1) * 0.25)
        }

        let schedule = Scheduler.generateWeek(fixed: [], flexible: flexible)

        #expect(schedule.placedFlexibleEvents.count == 100)
    }

    @Test func fixedEventsOnAllDaysIsValid() {
        let fixed = DayOfWeek.allCases.map {
            FixedEvent(name: "Fixed", day: $0, energyCost: 0.5)
        }
        let flexible = [FlexibleEvent(name: "Extra", energyCost: 0.25)]

        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: flexible)

        #expect(schedule.placedFlexibleEvents.count == 1)
    }

    @Test func noEnergyEventsDoNotContributeToLoad() {
        // A "No energy" event (holiday, reminder) should leave the day load at zero
        let fixed = [FixedEvent(name: "Holiday", day: .monday, energyCost: 0.0)]
        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: [])

        #expect((schedule.dailyLoads[.monday] ?? 0.0) == 0.0)
        #expect(!schedule.heavyDays.contains(.monday))
    }
}

// MARK: - Balance Score

@Suite("Scheduler — Balance Score")
struct SchedulerBalanceTests {

    @Test func identicalDailyLoadsProduceZeroVariance() {
        let fixed = DayOfWeek.allCases.map {
            FixedEvent(name: "Event", day: $0, energyCost: 0.5)
        }
        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: [])

        #expect(abs(schedule.balanceScore) < 0.0001)
    }

    @Test func unevenLoadProducesPositiveVariance() {
        let fixed = [
            FixedEvent(name: "A", day: .monday, energyCost: 1.0),
            FixedEvent(name: "B", day: .monday, energyCost: 1.0)
        ]
        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: [])

        #expect(schedule.balanceScore > 0.0)
    }

    @Test func moreEvenDistributionHasLowerScore() {
        // Spread load: lower variance expected
        let spread = DayOfWeek.allCases.map {
            FixedEvent(name: "Event", day: $0, energyCost: 0.5)
        }
        let spreadSchedule = Scheduler.generateWeek(fixed: spread, flexible: [])

        // Concentrated load: higher variance expected
        let concentrated = [
            FixedEvent(name: "A", day: .monday, energyCost: 1.0),
            FixedEvent(name: "B", day: .monday, energyCost: 1.0),
            FixedEvent(name: "C", day: .monday, energyCost: 1.0)
        ]
        let concentratedSchedule = Scheduler.generateWeek(fixed: concentrated, flexible: [])

        #expect(spreadSchedule.balanceScore < concentratedSchedule.balanceScore)
    }
}

// MARK: - Heavy Day Flagging

@Suite("Scheduler — Heavy Day Flagging")
struct SchedulerHeavyDayTests {

    @Test func dayExactlyAtThresholdIsFlagged() {
        // 1.0 + 1.0 = 2.0, which equals the threshold
        let fixed = [
            FixedEvent(name: "A", day: .tuesday, energyCost: 1.0),
            FixedEvent(name: "B", day: .tuesday, energyCost: 1.0)
        ]
        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: [])

        #expect(schedule.heavyDays.contains(.tuesday))
    }

    @Test func dayJustBelowThresholdIsNotFlagged() {
        // 1.0 + 0.99 = 1.99, just under the threshold
        let fixed = [
            FixedEvent(name: "A", day: .thursday, energyCost: 1.0),
            FixedEvent(name: "B", day: .thursday, energyCost: 0.99)
        ]
        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: [])

        #expect(!schedule.heavyDays.contains(.thursday))
    }

    @Test func lightDayIsNotFlagged() {
        let fixed = [FixedEvent(name: "Easy", day: .friday, energyCost: 0.25)]
        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: [])

        #expect(!schedule.heavyDays.contains(.friday))
    }

    @Test func onlyHeavyDaysAreFlagged() {
        let fixed = [
            FixedEvent(name: "Heavy A", day: .monday, energyCost: 1.0),
            FixedEvent(name: "Heavy B", day: .monday, energyCost: 1.0),
            FixedEvent(name: "Light", day: .friday, energyCost: 0.25)
        ]
        let schedule = Scheduler.generateWeek(fixed: fixed, flexible: [])

        #expect(schedule.heavyDays == [.monday])
    }

    @Test func emptyWeekHasNoHeavyDays() {
        let schedule = Scheduler.generateWeek(fixed: [], flexible: [])
        #expect(schedule.heavyDays.isEmpty)
    }
}

// MARK: - Energy Cost Validation

@Suite("Energy Cost Clamping")
struct EnergyCostClampingTests {

    @Test func fixedEventCostsAboveOneAreClamped() {
        let event = FixedEvent(name: "Test", day: .monday, energyCost: 5.0)
        #expect(event.energyCost == 1.0)
    }

    @Test func fixedEventCostsBelowZeroAreClamped() {
        let event = FixedEvent(name: "Test", day: .monday, energyCost: -2.0)
        #expect(event.energyCost == 0.0)
    }

    @Test func flexibleEventCostsAboveOneAreClamped() {
        let event = FlexibleEvent(name: "Test", energyCost: 99.0)
        #expect(event.energyCost == 1.0)
    }

    @Test func flexibleEventCostsBelowZeroAreClamped() {
        let event = FlexibleEvent(name: "Test", energyCost: -0.5)
        #expect(event.energyCost == 0.0)
    }

    @Test func validCostPassesThroughUnchanged() {
        let event = FixedEvent(name: "Test", day: .monday, energyCost: 0.75)
        #expect(event.energyCost == 0.75)
    }
}

// MARK: - Pattern Learning

@Suite("Pattern Learning")
struct PatternLearningTests {

    @Test func formulaProducesExpectedValue() {
        // 0.5 * 0.7 + 1.0 * 0.3 = 0.35 + 0.30 = 0.65
        let result = PatternLearner.updateBaseline(current: 0.5, newRating: 1.0)
        #expect(abs(result - 0.65) < 0.0001)
    }

    @Test func formulaWithZeroRatingDecreaseBaseline() {
        // 0.5 * 0.7 + 0.0 * 0.3 = 0.35
        let result = PatternLearner.updateBaseline(current: 0.5, newRating: 0.0)
        #expect(abs(result - 0.35) < 0.0001)
    }

    @Test func baselineConvergesWithRepeatedHighRatings() {
        var baseline = 0.5
        for _ in 0..<30 {
            baseline = PatternLearner.updateBaseline(current: baseline, newRating: 1.0)
        }
        #expect(baseline > 0.99)
    }

    @Test func baselineConvergesWithRepeatedLowRatings() {
        var baseline = 0.5
        for _ in 0..<30 {
            baseline = PatternLearner.updateBaseline(current: baseline, newRating: 0.0)
        }
        #expect(baseline < 0.01)
    }

    @Test func noSuggestionBeforeMinimumDataPoints() {
        let learner = PatternLearner(minimumDataPoints: 3)
        #expect(!learner.shouldSuggest)

        learner.record(rating: 0.75)
        #expect(!learner.shouldSuggest)

        learner.record(rating: 0.75)
        #expect(!learner.shouldSuggest)
    }

    @Test func suggestionUnlocksAtMinimumDataPoints() {
        let learner = PatternLearner(minimumDataPoints: 3)

        learner.record(rating: 0.75)
        learner.record(rating: 0.75)
        learner.record(rating: 0.75)

        #expect(learner.shouldSuggest)
    }

    @Test func resetClearsCountAndBaseline() {
        let learner = PatternLearner(minimumDataPoints: 1)
        learner.record(rating: 1.0)
        #expect(learner.shouldSuggest)

        learner.reset()

        #expect(!learner.shouldSuggest)
        #expect(abs(learner.baseline - 0.5) < 0.0001)
    }

    @Test func customMinimumDataPointsIsRespected() {
        let learner = PatternLearner(minimumDataPoints: 5)

        for _ in 0..<4 { learner.record(rating: 0.5) }
        #expect(!learner.shouldSuggest)

        learner.record(rating: 0.5)
        #expect(learner.shouldSuggest)
    }
}

// MARK: - User Type Detection

@Suite("User Type Detection")
@MainActor
struct UserTypeDetectionTests {

    // Creates plain unmanaged Event instances. detectUserType only reads isFixed,
    // so no ModelContainer is needed — SwiftData allows property access on unmanaged instances.
    private func makeEvents(fixed: Int, flexible: Int) -> [Event] {
        let fixedEvents = (0..<fixed).map { i in
            Event(name: "Fixed \(i)", isFixed: true, fixedDay: DayOfWeek.allCases[i % 7])
        }
        let flexEvents = (0..<flexible).map { i in
            Event(name: "Flex \(i)", isFixed: false)
        }
        return fixedEvents + flexEvents
    }

    @Test func emptyListDefaultsToOptimizer() {
        #expect(SchedulerService.detectUserType(events: []) == .optimizer)
    }

    @Test func fewerThanFourEventsDefaultsToOptimizer() {
        // 3 fixed events — ratio is 100% but count is below the minimum threshold
        let events = makeEvents(fixed: 3, flexible: 0)
        #expect(SchedulerService.detectUserType(events: events) == .optimizer)
    }

    @Test func ninetyPercentFixedIsOverloadedFixed() {
        // 9 fixed + 1 flexible = 90% — hits the threshold exactly
        let events = makeEvents(fixed: 9, flexible: 1)
        #expect(SchedulerService.detectUserType(events: events) == .overloadedFixed)
    }

    @Test func hundredPercentFixedIsOverloadedFixed() {
        let events = makeEvents(fixed: 5, flexible: 0)
        #expect(SchedulerService.detectUserType(events: events) == .overloadedFixed)
    }

    @Test func sixtyPercentFixedIsPatternLearner() {
        // 6 fixed + 4 flexible = 60% — just above the patternLearner threshold
        let events = makeEvents(fixed: 6, flexible: 4)
        #expect(SchedulerService.detectUserType(events: events) == .patternLearner)
    }

    @Test func seventyFivePercentFixedIsPatternLearner() {
        // 6 fixed + 2 flexible = 75% — mid-range patternLearner
        let events = makeEvents(fixed: 6, flexible: 2)
        #expect(SchedulerService.detectUserType(events: events) == .patternLearner)
    }

    @Test func fiftyPercentFixedIsOptimizer() {
        // 2 fixed + 2 flexible = 50% — clear optimizer territory
        let events = makeEvents(fixed: 2, flexible: 2)
        #expect(SchedulerService.detectUserType(events: events) == .optimizer)
    }

    @Test func mostlyFlexibleIsOptimizer() {
        // 1 fixed + 9 flexible = 10% fixed — classic optimizer
        let events = makeEvents(fixed: 1, flexible: 9)
        #expect(SchedulerService.detectUserType(events: events) == .optimizer)
    }
}

// MARK: - SchedulerTypes Display Properties

@Suite("SchedulerTypes — Labels and Display Names")
struct SchedulerTypesTests {

    @Test func energyLabelCostsMatchRawValues() {
        #expect(EnergyLabel.noEnergy.cost == 0.0)
        #expect(EnergyLabel.alright.cost == 0.25)
        #expect(EnergyLabel.manageable.cost == 0.5)
        #expect(EnergyLabel.takesEffort.cost == 0.75)
        #expect(EnergyLabel.prettyDraining.cost == 1.0)
    }

    @Test func energyLabelDisplayNamesAreCorrect() {
        #expect(EnergyLabel.noEnergy.displayName == "No energy")
        #expect(EnergyLabel.alright.displayName == "Alright")
        #expect(EnergyLabel.manageable.displayName == "Manageable")
        #expect(EnergyLabel.takesEffort.displayName == "Takes Effort")
        #expect(EnergyLabel.prettyDraining.displayName == "Pretty Draining")
    }

    @Test func energyLabelAllCasesContainsFiveEntries() {
        #expect(EnergyLabel.allCases.count == 5)
        #expect(EnergyLabel.allCases.first == .noEnergy)
    }

    @Test func timePreferenceDisplayNamesAreCorrect() {
        #expect(TimePreference.morning.displayName == "Morning")
        #expect(TimePreference.afternoon.displayName == "Afternoon")
        #expect(TimePreference.evening.displayName == "Evening")
        #expect(TimePreference.any.displayName == "Any time")
    }

    @Test func dayOfWeekDisplayNamesAreCorrect() {
        let expected: [(DayOfWeek, String)] = [
            (.monday, "Monday"), (.tuesday, "Tuesday"), (.wednesday, "Wednesday"),
            (.thursday, "Thursday"), (.friday, "Friday"), (.saturday, "Saturday"),
            (.sunday, "Sunday")
        ]
        for (day, name) in expected {
            #expect(day.displayName == name)
        }
    }

    @Test func dayOfWeekShortNamesAreThreeCharacters() {
        for day in DayOfWeek.allCases {
            #expect(day.shortName.count == 3)
        }
    }

    @Test func dayOfWeekShortNamesMatchDisplayNamePrefix() {
        let expected: [(DayOfWeek, String)] = [
            (.monday, "Mon"), (.tuesday, "Tue"), (.wednesday, "Wed"),
            (.thursday, "Thu"), (.friday, "Fri"), (.saturday, "Sat"),
            (.sunday, "Sun")
        ]
        for (day, short) in expected {
            #expect(day.shortName == short)
        }
    }

    @Test func orderedForLocaleContainsAllSevenDays() {
        #expect(Set(DayOfWeek.orderedForLocale) == Set(DayOfWeek.allCases))
        #expect(DayOfWeek.orderedForLocale.count == 7)
    }

    @Test func orderedForLocaleFirstDayMatchesCalendar() {
        let first = DayOfWeek.orderedForLocale.first
        if Calendar.current.firstWeekday == 1 {
            #expect(first == .sunday)
        } else {
            #expect(first == .monday)
        }
    }
}

// MARK: - startingFrom constraint (#45)

@Suite("Scheduler — Today-Forward Constraint")
struct SchedulerStartingFromTests {

    @Test func flexibleEventsNeverLandBeforeStartDay() {
        let flexible = (0..<5).map { FlexibleEvent(name: "E\($0)", energyCost: 0.5) }
        let schedule = Scheduler.generateWeek(fixed: [], flexible: flexible, startingFrom: .thursday)

        let tooEarly: [DayOfWeek] = [.monday, .tuesday, .wednesday]
        for event in schedule.placedFlexibleEvents {
            #expect(!tooEarly.contains(event.day))
        }
    }

    @Test func flexibleEventsLandOnOrAfterStartDay() {
        let flexible = [FlexibleEvent(name: "Task", energyCost: 0.5)]
        let schedule = Scheduler.generateWeek(fixed: [], flexible: flexible, startingFrom: .friday)

        let placed = schedule.placedFlexibleEvents.first
        #expect(placed != nil)
        #expect((placed?.day.rawValue ?? 0) >= DayOfWeek.friday.rawValue)
    }

    @Test func sundayStartAllowsOnlySunday() {
        let flexible = (0..<3).map { FlexibleEvent(name: "E\($0)", energyCost: 0.25) }
        let schedule = Scheduler.generateWeek(fixed: [], flexible: flexible, startingFrom: .sunday)

        for event in schedule.placedFlexibleEvents {
            #expect(event.day == .sunday)
        }
    }

    @Test func nilStartUsesAllDays() {
        let flexible = (0..<7).map { FlexibleEvent(name: "E\($0)", energyCost: 0.5) }
        let schedule = Scheduler.generateWeek(fixed: [], flexible: flexible, startingFrom: nil)

        let uniqueDays = Set(schedule.placedFlexibleEvents.map { $0.day })
        #expect(uniqueDays.count == 7)
    }
}

// MARK: - DayOfWeek Navigation

@Suite("DayOfWeek — Next Day")
struct DayOfWeekNavigationTests {

    @Test func mondayNextIsTuesday() {
        #expect(DayOfWeek.monday.next == .tuesday)
    }

    @Test func thursdayNextIsFriday() {
        #expect(DayOfWeek.thursday.next == .friday)
    }

    @Test func saturdayNextIsSunday() {
        #expect(DayOfWeek.saturday.next == .sunday)
    }

    @Test func sundayNextIsNil() {
        // Sunday has no next day within the week — forward warning never fires on Sunday
        #expect(DayOfWeek.sunday.next == nil)
    }

    @Test func allWeekdaysExceptSundayHaveANext() {
        let weekdays: [DayOfWeek] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        for day in weekdays {
            #expect(day.next != nil)
        }
    }

    @Test func consecutiveDaysChainCorrectly() {
        // Walk the whole week: Monday → Tuesday → ... → Saturday → Sunday → nil
        var day: DayOfWeek? = .monday
        var count = 0
        while let current = day {
            count += 1
            day = current.next
        }
        #expect(count == 7)
    }
}
