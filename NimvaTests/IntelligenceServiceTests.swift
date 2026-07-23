import Testing
import Foundation
@testable import Nimva

// Helpers — build fixed events with specific timing for deterministic tests
private func makeEvent(
    name: String = "Event",
    energyCost: Double,
    startHour: Int,
    startMinute: Int = 0,
    endHour: Int,
    endMinute: Int = 0
) -> Event {
    let cal  = Calendar.current
    let base = cal.startOfDay(for: Date())
    let start = cal.date(bySettingHour: startHour, minute: startMinute, second: 0, of: base)!
    let end   = cal.date(bySettingHour: endHour,   minute: endMinute,   second: 0, of: base)!
    return Event(
        name: name, isFixed: true, fixedDay: .monday,
        startTime: start, endTime: end,
        energyCost: energyCost
    )
}

// MARK: - Back-to-back streak tests (#58)

@Suite("BackToBack Detection")
struct BackToBackTests {

    @Test func emptyEventsReturnsZero() {
        #expect(IntelligenceService.backToBackStreak(events: []) == 0)
    }

    @Test func singleDrainingEventReturnsOne() {
        let event = makeEvent(energyCost: 0.75, startHour: 9, endHour: 10)
        #expect(IntelligenceService.backToBackStreak(events: [event]) == 1)
    }

    @Test func singleLightEventReturnsZero() {
        let event = makeEvent(energyCost: 0.25, startHour: 9, endHour: 10)
        #expect(IntelligenceService.backToBackStreak(events: [event]) == 0)
    }

    @Test func threeDrainingBackToBackReturnsThree() {
        // 9–10, 10:05–11:05, 11:10–12:10 — all draining, gaps < 15 min
        let a = makeEvent(energyCost: 0.75, startHour: 9,  endHour: 10)
        let b = makeEvent(energyCost: 1.0,  startHour: 10, startMinute: 5, endHour: 11, endMinute: 5)
        let c = makeEvent(energyCost: 0.75, startHour: 11, startMinute: 10, endHour: 12, endMinute: 10)
        #expect(IntelligenceService.backToBackStreak(events: [a, b, c]) == 3)
    }

    @Test func gapOver15MinBreaksStreak() {
        // 9–10, 10:20–11:20 — gap is 20 min, streak should reset
        let a = makeEvent(energyCost: 0.75, startHour: 9, endHour: 10)
        let b = makeEvent(energyCost: 0.75, startHour: 10, startMinute: 20, endHour: 11, endMinute: 20)
        #expect(IntelligenceService.backToBackStreak(events: [a, b]) == 1)
    }

    @Test func lightEventBreaksStreak() {
        // draining, light, draining — streak should be 1 not 2
        let a = makeEvent(energyCost: 0.75, startHour: 9,  endHour: 10)
        let b = makeEvent(energyCost: 0.25, startHour: 10, startMinute: 5, endHour: 11)
        let c = makeEvent(energyCost: 0.75, startHour: 11, startMinute: 5, endHour: 12)
        #expect(IntelligenceService.backToBackStreak(events: [a, b, c]) == 1)
    }

    @Test func flexibleEventsAreIgnored() {
        // Flexible events have no start/end time — should not count
        let flex = Event(name: "Flex", isFixed: false, energyCost: 1.0)
        #expect(IntelligenceService.backToBackStreak(events: [flex]) == 0)
    }

    @Test func streakCountsMaxNotTotal() {
        // Two separate streaks of 2 — max should be 2
        let a = makeEvent(energyCost: 0.75, startHour: 9,  endHour: 10)
        let b = makeEvent(energyCost: 0.75, startHour: 10, startMinute: 5,  endHour: 11)
        let c = makeEvent(energyCost: 0.25, startHour: 11, startMinute: 30, endHour: 12, endMinute: 30)
        let d = makeEvent(energyCost: 0.75, startHour: 13, endHour: 14)
        let e = makeEvent(energyCost: 0.75, startHour: 14, startMinute: 5,  endHour: 15)
        #expect(IntelligenceService.backToBackStreak(events: [a, b, c, d, e]) == 2)
    }
}

// MARK: - Recovery window tests (#55)

@Suite("Recovery Window Detection")
struct RecoveryWindowTests {

    @Test func emptyEventsReturnsEmpty() {
        #expect(IntelligenceService.recoveryWindows(events: []).isEmpty)
    }

    @Test func singleEventReturnsEmpty() {
        let a = makeEvent(energyCost: 0.75, startHour: 9, endHour: 10)
        #expect(IntelligenceService.recoveryWindows(events: [a]).isEmpty)
    }

    @Test func gapUnder15MinNotReturned() {
        let a = makeEvent(energyCost: 0.75, startHour: 9,  endHour: 10)
        let b = makeEvent(energyCost: 0.75, startHour: 10, startMinute: 10, endHour: 11, endMinute: 10)
        #expect(IntelligenceService.recoveryWindows(events: [a, b]).isEmpty)
    }

    @Test func gapExactly15MinIsReturned() {
        let a = makeEvent(energyCost: 0.75, startHour: 9,  endHour: 10)
        let b = makeEvent(energyCost: 0.75, startHour: 10, startMinute: 15, endHour: 11, endMinute: 15)
        let windows = IntelligenceService.recoveryWindows(events: [a, b])
        #expect(windows.count == 1)
        #expect(windows[0].durationMinutes == 15)
    }

    @Test func multipleWindowsReturnedLargestFirst() {
        let a = makeEvent(energyCost: 0.75, startHour: 8,  endHour: 9)
        let b = makeEvent(energyCost: 0.75, startHour: 10, endHour: 11)  // 60 min gap
        let c = makeEvent(energyCost: 0.75, startHour: 11, startMinute: 20, endHour: 12, endMinute: 20) // 20 min gap
        let d = makeEvent(energyCost: 0.75, startHour: 13, endHour: 14)  // 40 min gap
        let windows = IntelligenceService.recoveryWindows(events: [a, b, c, d])
        #expect(windows.count == 3)
        #expect(windows[0].durationMinutes == 60)
        #expect(windows[1].durationMinutes == 40)
        #expect(windows[2].durationMinutes == 20)
    }

    @Test func flexibleEventsIgnored() {
        let fixed = makeEvent(energyCost: 0.75, startHour: 9, endHour: 10)
        let flex  = Event(name: "Flex", isFixed: false, energyCost: 0.75)
        let windows = IntelligenceService.recoveryWindows(events: [fixed, flex])
        #expect(windows.isEmpty)
    }
}

// MARK: - Week load summary tests (#54)

@Suite("Week Load Summary")
struct WeekLoadSummaryTests {

    @Test func emptyLoadsReturnsEmpty() {
        #expect(IntelligenceService.weekLoadSummary(dailyLoads: [:]) == "")
    }

    @Test func allZeroLoadsReturnsEmpty() {
        let loads: [DayOfWeek: Double] = [.monday: 0, .tuesday: 0, .wednesday: 0]
        #expect(IntelligenceService.weekLoadSummary(dailyLoads: loads) == "")
    }

    @Test func lightWeekSummary() {
        let loads: [DayOfWeek: Double] = [.monday: 0.5, .tuesday: 0.3, .wednesday: 0.25]
        let summary = IntelligenceService.weekLoadSummary(dailyLoads: loads)
        #expect(summary == "Light week overall.")
    }

    @Test func moderateWeekNameHeaviestDay() {
        let loads: [DayOfWeek: Double] = [.monday: 1.0, .tuesday: 0.5, .wednesday: 2.0, .thursday: 0.5]
        let summary = IntelligenceService.weekLoadSummary(dailyLoads: loads)
        #expect(summary.contains("Wednesday"))
        #expect(summary.contains("Moderate"))
    }

    @Test func heavyWeekNameHeaviestDay() {
        let loads: [DayOfWeek: Double] = [.monday: 2.0, .tuesday: 1.5, .wednesday: 3.0, .thursday: 1.0]
        let summary = IntelligenceService.weekLoadSummary(dailyLoads: loads)
        #expect(summary.contains("Wednesday"))
        #expect(summary.contains("Heavy"))
    }
}

// MARK: - Category breakdown tests (#61)

@Suite("Category Breakdown")
struct CategoryBreakdownTests {

    @Test func fewerThanThreeDrainingReturnsNil() {
        let events = [
            Event(name: "A", isFixed: true, energyCost: 0.75, category: "School"),
            Event(name: "B", isFixed: true, energyCost: 0.75, category: "School")
        ]
        #expect(IntelligenceService.dominantDrainCategory(events: events) == nil)
    }

    @Test func dominantCategoryDetected() {
        let events = [
            Event(name: "A", isFixed: true, energyCost: 0.75, category: "School"),
            Event(name: "B", isFixed: true, energyCost: 0.75, category: "School"),
            Event(name: "C", isFixed: true, energyCost: 0.75, category: "School"),
            Event(name: "D", isFixed: true, energyCost: 0.25, category: "Personal")
        ]
        let result = IntelligenceService.dominantDrainCategory(events: events)
        #expect(result?.category == "School")
    }

    @Test func balancedCategoriesReturnsNil() {
        let events = [
            Event(name: "A", isFixed: true, energyCost: 0.75, category: "School"),
            Event(name: "B", isFixed: true, energyCost: 0.75, category: "Work"),
            Event(name: "C", isFixed: true, energyCost: 0.75, category: "Personal")
        ]
        #expect(IntelligenceService.dominantDrainCategory(events: events) == nil)
    }
}

// MARK: - Overloaded week note tests (#56)

@Suite("Overloaded Week Note")
struct OverloadedWeekNoteTests {

    @Test func emptyLoadsReturnsEmpty() {
        #expect(IntelligenceService.overloadedWeekNote(dailyLoads: [:]) == "")
    }

    @Test func allZeroLoadsReturnsEmpty() {
        let loads: [DayOfWeek: Double] = [.monday: 0, .tuesday: 0]
        #expect(IntelligenceService.overloadedWeekNote(dailyLoads: loads) == "")
    }

    @Test func noHeavyDaysMentionsFixed() {
        // Load present but below threshold on all days
        let loads: [DayOfWeek: Double] = [.monday: 0.5, .tuesday: 1.0, .wednesday: 0.75]
        let note = IntelligenceService.overloadedWeekNote(dailyLoads: loads)
        #expect(note.contains("fixed"))
    }

    @Test func oneHeavyDayNamesIt() {
        let loads: [DayOfWeek: Double] = [.wednesday: 2.5, .thursday: 0.5]
        let note = IntelligenceService.overloadedWeekNote(dailyLoads: loads)
        #expect(note.contains("Wednesday"))
    }

    @Test func threeHeavyDaysIncludesCount() {
        let loads: [DayOfWeek: Double] = [
            .monday: 2.5, .wednesday: 2.1, .friday: 3.0,
            .tuesday: 0.5, .thursday: 0.5
        ]
        let note = IntelligenceService.overloadedWeekNote(dailyLoads: loads)
        #expect(note.contains("3"))
    }

    @Test func fivePlusHeavyDaysUsesMostDaysMessage() {
        var loads: [DayOfWeek: Double] = [:]
        for day in DayOfWeek.allCases.prefix(5) { loads[day] = 2.5 }
        let note = IntelligenceService.overloadedWeekNote(dailyLoads: loads)
        #expect(note.contains("Most"))
    }

    // #86 — a "this week is genuinely unsustainable" style message must never be left
    // bare; every heavy-week branch pairs it with a concrete, controllable action.
    @Test func oneHeavyDayPairsAnAction() {
        let loads: [DayOfWeek: Double] = [.wednesday: 2.5, .thursday: 0.5]
        let note = IntelligenceService.overloadedWeekNote(dailyLoads: loads)
        #expect(note.contains("protect"))
    }

    @Test func threeHeavyDaysPairsAnAction() {
        let loads: [DayOfWeek: Double] = [
            .monday: 2.5, .wednesday: 2.1, .friday: 3.0,
            .tuesday: 0.5, .thursday: 0.5
        ]
        let note = IntelligenceService.overloadedWeekNote(dailyLoads: loads)
        #expect(note.contains("protect"))
    }

    @Test func fivePlusHeavyDaysPairsAnAction() {
        var loads: [DayOfWeek: Double] = [:]
        for day in DayOfWeek.allCases.prefix(5) { loads[day] = 2.5 }
        let note = IntelligenceService.overloadedWeekNote(dailyLoads: loads)
        #expect(note.contains("protect"))
    }
}

// MARK: - Forward warning tests (#57)

@Suite("Forward Warning")
struct ForwardWarningTests {

    @Test func sundayReturnsEmpty() {
        // Sunday has no next day in the week
        #expect(IntelligenceService.forwardWarning(today: .sunday, tomorrowDrainingCount: 5) == "")
    }

    @Test func fewerThanThreeDrainingReturnsEmpty() {
        #expect(IntelligenceService.forwardWarning(today: .monday, tomorrowDrainingCount: 2) == "")
        #expect(IntelligenceService.forwardWarning(today: .monday, tomorrowDrainingCount: 0) == "")
    }

    @Test func exactlyThreeDrainingFiresWarning() {
        let warning = IntelligenceService.forwardWarning(today: .monday, tomorrowDrainingCount: 3)
        #expect(!warning.isEmpty)
        #expect(warning.contains("Tuesday"))
        #expect(warning.contains("3"))
    }

    @Test func warningNamesTomorrowCorrectly() {
        let warning = IntelligenceService.forwardWarning(today: .thursday, tomorrowDrainingCount: 4)
        #expect(warning.contains("Friday"))
        #expect(warning.contains("4"))
    }

    @Test func saturdayWarnsAboutSunday() {
        let warning = IntelligenceService.forwardWarning(today: .saturday, tomorrowDrainingCount: 3)
        #expect(warning.contains("Sunday"))
    }
}

// MARK: - Lightest upcoming day tests (#59)

@Suite("Lightest Upcoming Day")
struct LightestUpcomingDayTests {

    @Test func emptyLoadsReturnsNil() {
        #expect(IntelligenceService.lightestUpcomingDay(dailyLoads: [:], from: .monday) == nil)
    }

    @Test func allZeroLoadsReturnsNil() {
        let loads: [DayOfWeek: Double] = [.tuesday: 0, .wednesday: 0, .thursday: 0]
        #expect(IntelligenceService.lightestUpcomingDay(dailyLoads: loads, from: .monday) == nil)
    }

    @Test func singleDayWithLoadReturnsThatDay() {
        let loads: [DayOfWeek: Double] = [.wednesday: 1.5]
        #expect(IntelligenceService.lightestUpcomingDay(dailyLoads: loads, from: .monday) == .wednesday)
    }

    @Test func returnsLightestNotFirstDay() {
        let loads: [DayOfWeek: Double] = [.tuesday: 2.0, .wednesday: 0.5, .thursday: 1.5]
        #expect(IntelligenceService.lightestUpcomingDay(dailyLoads: loads, from: .monday) == .wednesday)
    }

    @Test func dayBeforeTodayIsExcluded() {
        // Monday has the lightest load, but from: .wednesday excludes it
        let loads: [DayOfWeek: Double] = [.monday: 0.1, .wednesday: 1.0, .thursday: 2.0]
        let result = IntelligenceService.lightestUpcomingDay(dailyLoads: loads, from: .wednesday)
        #expect(result != .monday)
        #expect(result == .wednesday)
    }

    @Test func todayIsIncluded() {
        let loads: [DayOfWeek: Double] = [.friday: 0.5, .saturday: 1.0]
        #expect(IntelligenceService.lightestUpcomingDay(dailyLoads: loads, from: .friday) == .friday)
    }

    @Test func sundayFromSundayOnlyReturnsSunday() {
        let loads: [DayOfWeek: Double] = [.monday: 0.1, .friday: 0.5, .sunday: 1.5]
        #expect(IntelligenceService.lightestUpcomingDay(dailyLoads: loads, from: .sunday) == .sunday)
    }
}

// MARK: - Daily note integration tests (#53)

@Suite("Daily Note")
struct DailyNoteTests {

    @Test func emptyEventsReturnsEmpty() {
        #expect(IntelligenceService.dailyNote(events: []) == "")
    }

    @Test func singleLightEventReturnsEmpty() {
        let event = makeEvent(energyCost: 0.25, startHour: 9, endHour: 10)
        #expect(IntelligenceService.dailyNote(events: [event]) == "")
    }

    @Test func threeDrainingBackToBackMentionsStreak() {
        let a = makeEvent(energyCost: 0.75, startHour: 9,  endHour: 10)
        let b = makeEvent(energyCost: 1.0,  startHour: 10, startMinute: 5, endHour: 11, endMinute: 5)
        let c = makeEvent(energyCost: 0.75, startHour: 11, startMinute: 10, endHour: 12, endMinute: 10)
        let note = IntelligenceService.dailyNote(events: [a, b, c])
        #expect(note.contains("3"))
        #expect(note.contains("back to back"))
    }

    @Test func recoveryWindowWithDrainingMentionsGap() {
        // Draining event 9–10, then light break, then 10:30–11:30 (30 min gap)
        let draining = makeEvent(energyCost: 0.75, startHour: 9, endHour: 10)
        let later    = makeEvent(energyCost: 0.25, startHour: 10, startMinute: 30, endHour: 11, endMinute: 30)
        let note = IntelligenceService.dailyNote(events: [draining, later])
        #expect(note.contains("recovery window"))
        #expect(note.contains("30m"))
    }

    @Test func threeDrainingFlexEventsNoTimesGivesCount() {
        // Flexible events have no start/end — no streak, no recovery windows, but drainingCount >= 3
        let events = (0..<3).map { _ in Event(name: "Task", isFixed: false, energyCost: 0.75) }
        let note = IntelligenceService.dailyNote(events: events)
        #expect(note.contains("3"))
        #expect(note.contains("draining"))
    }

    @Test func twoDrainingNoRecoveryReturnsEmpty() {
        // 2 draining events with a gap — recovery window fires, but only 2 draining
        // Actually: recoveryWindows fires first (window + drainingCount>=1). Let's test 2 draining no windows.
        let a = makeEvent(energyCost: 0.75, startHour: 9,  endHour: 10)
        let b = makeEvent(energyCost: 0.75, startHour: 10, startMinute: 5, endHour: 11)
        // Gap is 5 min — no recovery window. Streak is 2, not >= 3. drainingCount is 2, not >= 3.
        let note = IntelligenceService.dailyNote(events: [a, b])
        #expect(note == "")
    }
}
