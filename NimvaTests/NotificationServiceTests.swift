import Testing
import Foundation
@testable import Nimva

@Suite("NotificationService")
struct NotificationServiceTests {

    // A week comfortably in the future relative to "now" for every test, so no spec ever
    // gets filtered out for having already passed — that filtering is tested separately.
    private var futureWeekStart: Date {
        SchedulerService.weekStart(offsetWeeks: 4)
    }

    private func makeCache(dailyLoadValues: [Double], heavyDayValues: [Int] = [], weekStart: Date? = nil) -> WeekCache {
        WeekCache(
            weekStartDate: weekStart ?? futureWeekStart,
            placementsJSON: "[]",
            balanceScore: 0,
            heavyDayValues: heavyDayValues,
            dailyLoadValues: dailyLoadValues
        )
    }

    // MARK: - heavyDayWarnings

    @Test func oneWarningPerHeavyDay() {
        let cache = makeCache(dailyLoadValues: [], heavyDayValues: [DayOfWeek.tuesday.rawValue, DayOfWeek.thursday.rawValue])
        let warnings = NotificationService.heavyDayWarnings(for: cache, idPrefix: "test")
        #expect(warnings.count == 2)
        #expect(warnings.allSatisfy { $0.body.contains("heavy day") })
    }

    @Test func heavyWarningFiresTheEveningBefore() {
        let cache = makeCache(dailyLoadValues: [], heavyDayValues: [DayOfWeek.wednesday.rawValue])
        let warning = try! #require(NotificationService.heavyDayWarnings(for: cache, idPrefix: "test").first)
        let wednesdayDate = SchedulerService.date(for: .wednesday, weekStart: cache.weekStartDate)
        let expectedEvening = Calendar.current.date(byAdding: .day, value: -1, to: wednesdayDate)!
        #expect(Calendar.current.isDate(warning.fireDate, inSameDayAs: expectedEvening))
        #expect(Calendar.current.component(.hour, from: warning.fireDate) == 20)
    }

    @Test func noHeavyDaysProducesNoWarnings() {
        let cache = makeCache(dailyLoadValues: [], heavyDayValues: [])
        #expect(NotificationService.heavyDayWarnings(for: cache, idPrefix: "test").isEmpty)
    }

    // MARK: - lightestDayNudge

    @Test func nudgesTheSingleLightestDay() {
        // Every day non-zero — Wednesday (index 2) is the plain lowest.
        let cache = makeCache(dailyLoadValues: [0.9, 0.5, 0.1, 0.8, 0.6, 0.3, 0.4])
        let nudge = try! #require(NotificationService.lightestDayNudge(for: cache, idPrefix: "test"))
        #expect(nudge.identifier.hasSuffix("light.\(DayOfWeek.wednesday.rawValue)"))
    }

    @Test func nudgeFiresInTheMorning() {
        let cache = makeCache(dailyLoadValues: [0.1, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9])
        let nudge = try! #require(NotificationService.lightestDayNudge(for: cache, idPrefix: "test"))
        #expect(Calendar.current.component(.hour, from: nudge.fireDate) == 9)
    }

    @Test func noNudgeWhenLightestDayIsCompletelyEmpty() {
        // Nothing to "take a break" from on a day with zero load at all — every other day is
        // moderate (1.0–2.0, not light), so once the empty day is correctly excluded, there's
        // no genuinely light non-empty day left to nudge about.
        let cache = makeCache(dailyLoadValues: [1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 0.0])
        #expect(NotificationService.lightestDayNudge(for: cache, idPrefix: "test") == nil)
    }

    @Test func noNudgeWhenTheLightestDayStillClassifiesAsModerateOrHeavy() {
        // Every day is at least moderately loaded — no day qualifies as "light."
        let cache = makeCache(dailyLoadValues: [1.5, 1.6, 1.4, 1.9, 1.5, 1.7, 1.8])
        #expect(NotificationService.lightestDayNudge(for: cache, idPrefix: "test") == nil)
    }

    @Test func emptyWeekendDayDoesNotSuppressTheRealLightestDay() {
        // Regression: an empty Saturday/Sunday (extremely common) is a lower raw number than
        // any non-zero light day, but "nothing scheduled at all" isn't the day worth nudging
        // about — Wednesday (0.1, genuinely light but not empty) should still win.
        let cache = makeCache(dailyLoadValues: [0.9, 0.5, 0.1, 0.8, 0.6, 0.0, 0.0])
        let nudge = try! #require(NotificationService.lightestDayNudge(for: cache, idPrefix: "test"))
        #expect(nudge.identifier.hasSuffix("light.\(DayOfWeek.wednesday.rawValue)"))
    }

    @Test func emptyDailyLoadValuesProducesNoNudge() {
        // Defensive: a WeekCache built before dailyLoadValues existed.
        let cache = makeCache(dailyLoadValues: [])
        #expect(NotificationService.lightestDayNudge(for: cache, idPrefix: "test") == nil)
    }

    // MARK: - weeklyCheckInReminder / newWeekReminder

    @Test func checkInReminderFiresSundayEvening() {
        let cache = makeCache(dailyLoadValues: [])
        let reminder = try! #require(NotificationService.weeklyCheckInReminder(for: cache, idPrefix: "test"))
        let sundayDate = SchedulerService.date(for: .sunday, weekStart: cache.weekStartDate)
        #expect(Calendar.current.isDate(reminder.fireDate, inSameDayAs: sundayDate))
        #expect(Calendar.current.component(.hour, from: reminder.fireDate) == 19)
    }

    @Test func newWeekReminderFiresMondayMorningOfTheFollowingWeek() {
        let cache = makeCache(dailyLoadValues: [])
        let reminder = try! #require(NotificationService.newWeekReminder(for: cache, idPrefix: "test"))
        let nextWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: cache.weekStartDate)!
        let mondayDate = SchedulerService.date(for: .monday, weekStart: nextWeekStart)
        #expect(Calendar.current.isDate(reminder.fireDate, inSameDayAs: mondayDate))
        #expect(Calendar.current.component(.hour, from: reminder.fireDate) == 9)
        // Sanity: the new-week reminder must land in a later week than the one just built,
        // never the same week or earlier.
        #expect(reminder.fireDate > cache.weekStartDate)
    }

    // MARK: - specs(for:...) — toggles and past-date filtering

    @Test func allTogglesOffProducesNoSpecs() {
        let cache = makeCache(dailyLoadValues: [0.1, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9], heavyDayValues: [DayOfWeek.tuesday.rawValue])
        let specs = NotificationService.specs(
            for: cache, dailyNudgesEnabled: false, checkInReminderEnabled: false, newWeekReminderEnabled: false
        )
        #expect(specs.isEmpty)
    }

    @Test func onlyDailyNudgesToggleProducesHeavyAndLightSpecsOnly() {
        let cache = makeCache(dailyLoadValues: [0.1, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9], heavyDayValues: [DayOfWeek.tuesday.rawValue])
        let specs = NotificationService.specs(
            for: cache, dailyNudgesEnabled: true, checkInReminderEnabled: false, newWeekReminderEnabled: false
        )
        #expect(specs.count == 2)   // one heavy warning + one light nudge
        #expect(specs.allSatisfy { $0.identifier.contains(".heavy.") || $0.identifier.contains(".light.") })
    }

    @Test func pastFireDatesAreFilteredOut() {
        // A week that's already fully elapsed — every spec's fireDate is in the past relative
        // to "now", so nothing should survive the filter regardless of which toggles are on.
        let pastWeek = SchedulerService.weekStart(offsetWeeks: -3)
        let cache = makeCache(dailyLoadValues: [0.1, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9], heavyDayValues: [DayOfWeek.tuesday.rawValue], weekStart: pastWeek)
        let specs = NotificationService.specs(
            for: cache, dailyNudgesEnabled: true, checkInReminderEnabled: true, newWeekReminderEnabled: true, now: Date()
        )
        #expect(specs.isEmpty)
    }

    @Test func identifiersAreUniqueAndPrefixedForTheWeek() {
        let cache = makeCache(dailyLoadValues: [0.1, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9], heavyDayValues: [DayOfWeek.tuesday.rawValue, DayOfWeek.thursday.rawValue])
        let specs = NotificationService.specs(
            for: cache, dailyNudgesEnabled: true, checkInReminderEnabled: true, newWeekReminderEnabled: true
        )
        let ids = specs.map(\.identifier)
        #expect(Set(ids).count == ids.count)
        let prefix = NotificationService.identifierPrefix(for: cache.weekStartDate)
        #expect(ids.allSatisfy { $0.hasPrefix(prefix) })
    }
}
