import Foundation

// Generates what a notification should say and when it should fire, for one freshly-built
// current week — fully testable, deliberately separate from NotificationScheduler (the thin
// UNUserNotificationCenter wrapper), matching the existing pattern of keeping system-API
// wrappers minimal and pushing the actual logic somewhere it can be tested directly (see
// ProService/CalendarImportService).
//
// Kept deliberately light-touch, per the explicit ask that this "isn't too annoying and
// doesn't appear much": a heavy-day warning fires for each real heavy day (each one is
// individually actionable, so this isn't excessive), but the light-day nudge only fires once
// for the single lightest day of the week rather than every day that happens to classify as
// "light" — the point is for it to feel like a small, occasional acknowledgment, not a
// routine ping. Plus the two weekly-cadence reminders (check-in, new week), one each.
enum NotificationService {
    struct Spec: Equatable, Sendable {
        let identifier: String
        let title: String
        let body: String
        let fireDate: Date
    }

    // A plain, Sendable snapshot of exactly the WeekCache fields this whole file needs.
    // Every function here takes this instead of a live WeekCache (a SwiftData @Model
    // reference type) specifically so a caller can extract it synchronously and never hold
    // an actual model reference across an `await` — reading a SwiftData object's properties
    // after a suspension point risks racing a concurrent mutation/save on the context's own
    // thread. See NotificationScheduler.rescheduleForCurrentWeek, which builds this before
    // entering its async Task.
    struct Snapshot: Equatable, Sendable {
        let weekStartDate: Date
        let heavyDayValues: [Int]
        let dailyLoadValues: [Double]

        init(weekStartDate: Date, heavyDayValues: [Int], dailyLoadValues: [Double]) {
            self.weekStartDate = weekStartDate
            self.heavyDayValues = heavyDayValues
            self.dailyLoadValues = dailyLoadValues
        }

        init(_ cache: WeekCache) {
            weekStartDate = cache.weekStartDate
            heavyDayValues = cache.heavyDayValues
            dailyLoadValues = cache.dailyLoadValues
        }
    }

    // MARK: - Personalized baseline (#15, PRO)

    /// This user's own historical average load per day-of-week, across past built weeks —
    /// the "lighter than *your* usual" comparison basis #15's capacity alert needs, distinct
    /// from lightestDayNudge's fixed absolute-threshold check below (which only knows "light
    /// in general," not "light for a Tuesday specifically").
    struct HistoricalBaseline: Equatable, Sendable {
        let averageLoadByDay: [Int: Double]   // DayOfWeek.rawValue -> average load
        let weeksConsidered: Int

        /// Builds a baseline from past weeks' full 7-value dailyLoadValues arrays (index
        /// 0 = Monday ... 6 = Sunday, matching WeekCache's own storage convention — stable
        /// regardless of device locale). Any array that isn't exactly 7 long is a WeekCache
        /// built before dailyLoadValues existed (empty, per its own doc comment) and is
        /// filtered out rather than silently treated as an all-light week. Returns nil below
        /// `minimumWeeks` of real data — a "lighter than your usual" claim needs an actual
        /// usual to compare against, not one or two data points (same bar PatternService's
        /// own minimumPoints uses for a baseline claim).
        static func build(from pastDailyLoadValues: [[Double]], minimumWeeks: Int = 3) -> HistoricalBaseline? {
            let validWeeks = pastDailyLoadValues.filter { $0.count == 7 }
            guard validWeeks.count >= minimumWeeks else { return nil }
            var averages: [Int: Double] = [:]
            for index in 0..<7 {
                let values = validWeeks.map { $0[index] }
                averages[index + 1] = values.reduce(0, +) / Double(values.count)
            }
            return HistoricalBaseline(averageLoadByDay: averages, weeksConsidered: validWeeks.count)
        }

        /// True when `load` on `day` sits meaningfully below this user's own historical
        /// average for that specific day-of-week. A day with no real history (never built
        /// before, average == 0) can't be judged "lighter than usual" — there's no usual yet.
        func isLighterThanUsual(_ load: Double, on day: DayOfWeek) -> Bool {
            guard let average = averageLoadByDay[day.rawValue], average > 0 else { return false }
            return load <= average * 0.7
        }
    }

    // Stable per-week prefix so a rebuild can find and cancel exactly this week's previously
    // scheduled notifications before scheduling the fresh set, without touching any other
    // week's (e.g. a future rolling-calendar week's) pending notifications.
    static func identifierPrefix(for weekStart: Date) -> String {
        "nimva.week.\(Int(weekStart.timeIntervalSince1970))"
    }

    /// Every notification worth scheduling for this newly-built current week, filtered to
    /// only ones that haven't already passed (a background rebuild mid-week shouldn't try to
    /// schedule "tomorrow was heavy" for a day that's already gone by).
    static func specs(
        for snapshot: Snapshot,
        dailyNudgesEnabled: Bool,
        checkInReminderEnabled: Bool,
        newWeekReminderEnabled: Bool,
        personalizedBaseline: HistoricalBaseline? = nil,
        now: Date = Date()
    ) -> [Spec] {
        var result: [Spec] = []
        let prefix = identifierPrefix(for: snapshot.weekStartDate)

        if dailyNudgesEnabled {
            result += heavyDayWarnings(for: snapshot, idPrefix: prefix)
            if let nudge = lightestDayNudge(for: snapshot, idPrefix: prefix, personalizedBaseline: personalizedBaseline) {
                result.append(nudge)
            }
        }
        if checkInReminderEnabled, let checkIn = weeklyCheckInReminder(for: snapshot, idPrefix: prefix) {
            result.append(checkIn)
        }
        if newWeekReminderEnabled, let newWeek = newWeekReminder(for: snapshot, idPrefix: prefix) {
            result.append(newWeek)
        }
        return result.filter { $0.fireDate > now }
    }

    // MARK: - Heavy-day warning — evening before each real heavy day

    static func heavyDayWarnings(for snapshot: Snapshot, idPrefix: String) -> [Spec] {
        snapshot.heavyDayValues.compactMap { rawValue -> Spec? in
            guard let day = DayOfWeek(rawValue: rawValue),
                  let evening = timeOn(day, weekStart: snapshot.weekStartDate, dayOffset: -1, hour: 20)
            else { return nil }
            return Spec(
                identifier: "\(idPrefix).heavy.\(rawValue)",
                title: "Heads up for tomorrow",
                body: "\(day.displayName) is expected to be a heavy day.",
                fireDate: evening
            )
        }
    }

    // MARK: - Light-day nudge — the single lightest (but non-empty) day of the week, once

    static func lightestDayNudge(for snapshot: Snapshot, idPrefix: String, personalizedBaseline: HistoricalBaseline? = nil) -> Spec? {
        guard !snapshot.dailyLoadValues.isEmpty else { return nil }
        // Filter to non-empty days *before* finding the minimum, not after — a completely
        // empty Saturday/Sunday (extremely common) would otherwise always BE the global
        // minimum, silently suppressing this nudge in the exact weeks it'd be most relevant.
        // Nothing to "take a break" from on a genuinely empty day, but that's a different
        // question from "which real day had the least on it."
        let nonEmpty = Array(snapshot.dailyLoadValues.enumerated()).filter { $0.element > 0 }
        guard let lightest = nonEmpty.min(by: { $0.element < $1.element }),
              LoadSeverity.forLoad(lightest.element) == .light,
              let day = DayOfWeek(rawValue: lightest.offset + 1),
              let morning = timeOn(day, weekStart: snapshot.weekStartDate, dayOffset: 0, hour: 9)
        else { return nil }

        // #15 (PRO): upgrades this SAME day's nudge to the personalized "lighter than your
        // usual" framing when the history backs that stronger claim — never a second,
        // separate notification on top of it. Deliberately scoped to only ever touch the day
        // the free nudge already picked, so this can never increase how often anything fires.
        if let baseline = personalizedBaseline, baseline.isLighterThanUsual(lightest.element, on: day) {
            return Spec(
                identifier: "\(idPrefix).light.\(day.rawValue)",
                title: "Lighter day than usual",
                body: "\(day.displayName) looks lighter than your usual — a good window to tackle something draining you've been putting off.",
                fireDate: morning
            )
        }
        return Spec(
            identifier: "\(idPrefix).light.\(day.rawValue)",
            title: "Lighter day today",
            body: "Today's a good day to take a little break — you've earned some rest.",
            fireDate: morning
        )
    }

    // MARK: - Weekly check-in reminder — Sunday evening (existing Settings toggle, now wired)

    static func weeklyCheckInReminder(for snapshot: Snapshot, idPrefix: String) -> Spec? {
        guard let evening = timeOn(.sunday, weekStart: snapshot.weekStartDate, dayOffset: 0, hour: 19) else { return nil }
        return Spec(
            identifier: "\(idPrefix).checkin",
            title: "Week's almost done",
            body: "Take a minute to check in — see how the week actually went.",
            fireDate: evening
        )
    }

    // MARK: - New week reminder — Monday morning of the following week

    static func newWeekReminder(for snapshot: Snapshot, idPrefix: String) -> Spec? {
        guard let nextWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: snapshot.weekStartDate),
              let morning = timeOn(.monday, weekStart: nextWeekStart, dayOffset: 0, hour: 9)
        else { return nil }
        return Spec(
            identifier: "\(idPrefix).newweek",
            title: "New week, new start",
            body: "Set up your new week when you're ready — tap Build my week in the Plan tab.",
            fireDate: morning
        )
    }

    // MARK: - Time helper

    // Resolves `day` to a real calendar date within the week starting at `weekStart` (via
    // SchedulerService.date(for:weekStart:), so this is correct regardless of device locale —
    // see its own doc comment), then shifts by `dayOffset` real calendar days (-1 = the
    // evening before) and sets the given hour. Deliberately does real date arithmetic rather
    // than reasoning about DayOfWeek labels for the offset, which sidesteps the whole
    // locale/Sunday-ordering question entirely (see the Stray Spark Log) — "the evening
    // before Monday" is just "one real day earlier," regardless of which day nominally
    // starts the week.
    private static func timeOn(_ day: DayOfWeek, weekStart: Date, dayOffset: Int, hour: Int) -> Date? {
        let cal = Calendar.current
        let dayDate = SchedulerService.date(for: day, weekStart: weekStart)
        guard let shifted = cal.date(byAdding: .day, value: dayOffset, to: dayDate) else { return nil }
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: shifted)
    }
}
