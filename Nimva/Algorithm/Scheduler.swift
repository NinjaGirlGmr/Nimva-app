import Foundation

enum Scheduler {
    // Adjustable — will be validated against real user data during testing
    static let heavyDayThreshold: Double = 2.0

    static func generateWeek(
        fixed: [FixedEvent],
        flexible: [FlexibleEvent],
        startingFrom today: DayOfWeek? = nil
    ) -> WeekSchedule {
        // Seed all 7 days at zero so every day is always represented
        var dailyLoads: [DayOfWeek: Double] = Dictionary(
            uniqueKeysWithValues: DayOfWeek.allCases.map { ($0, 0.0) }
        )

        for event in fixed {
            dailyLoads[event.day, default: 0.0] += event.energyCost
        }

        // Flexible events may only land on today or later — never on a day that has passed.
        let eligibleDays: [DayOfWeek]
        if let from = today {
            eligibleDays = DayOfWeek.allCases.filter { $0.rawValue >= from.rawValue }
        } else {
            eligibleDays = DayOfWeek.allCases
        }

        // LPT order: highest energy cost first so heavy events get the lightest days
        let sorted = flexible.sorted { $0.energyCost > $1.energyCost }

        var placed: [PlacedEvent] = []
        var overflow: [FlexibleEvent] = []

        for event in sorted {
            // Recovery gap protection (#60): prefer non-heavy days so flexible events
            // don't pile onto days that are already at the heavy threshold. If every
            // eligible day is already heavy, fall back to the least-loaded option
            // rather than overflowing — the user's schedule is just packed.
            let nonHeavy = eligibleDays.filter { dailyLoads[$0, default: 0.0] < heavyDayThreshold }
            let allEligibleWereHeavy = nonHeavy.isEmpty
            let candidates = allEligibleWereHeavy ? eligibleDays : nonHeavy

            guard let bestDay = candidates.min(by: {
                dailyLoads[$0, default: 0.0] < dailyLoads[$1, default: 0.0]
            }) else {
                overflow.append(event)
                continue
            }

            let reason = placementReason(
                day: bestDay,
                candidates: candidates,
                dailyLoads: dailyLoads,
                allEligibleWereHeavy: allEligibleWereHeavy
            )
            placed.append(PlacedEvent(event: event, day: bestDay, reason: reason))
            dailyLoads[bestDay, default: 0.0] += event.energyCost
        }

        // Balance score = variance of daily loads across all 7 days (lower = more balanced)
        let loads = DayOfWeek.allCases.map { dailyLoads[$0, default: 0.0] }
        let mean = loads.reduce(0, +) / Double(loads.count)
        let variance = loads.map { pow($0 - mean, 2) }.reduce(0, +) / Double(loads.count)

        let heavyDays = Set(dailyLoads.filter { $0.value >= heavyDayThreshold }.keys)

        return WeekSchedule(
            fixedEvents: fixed,
            placedFlexibleEvents: placed,
            overflowEvents: overflow,
            dailyLoads: dailyLoads,
            balanceScore: variance,
            heavyDays: heavyDays
        )
    }

    // MARK: - Placement reason (#62)

    /// Produces a one-line factual explanation of why this day was chosen.
    /// Four outcomes, in priority order:
    ///   1. All eligible days were heavy — honest fallback message.
    ///   2. Only one candidate — lightest available day.
    ///   3. Clear load gap (≥ 0.5) vs the next lightest option — "noticeably lighter."
    ///   4. Standard lowest-load pick.
    private static func placementReason(
        day: DayOfWeek,
        candidates: [DayOfWeek],
        dailyLoads: [DayOfWeek: Double],
        allEligibleWereHeavy: Bool
    ) -> String {
        if allEligibleWereHeavy {
            return "\(day.displayName) — no lighter days available this week."
        }

        let others = candidates.filter { $0 != day }.map { dailyLoads[$0, default: 0.0] }

        if others.isEmpty {
            return "\(day.displayName) — lightest available day this week."
        }

        let chosenLoad  = dailyLoads[day, default: 0.0]
        let nextLightest = others.min() ?? chosenLoad

        if nextLightest - chosenLoad >= 0.5 {
            return "\(day.displayName) — noticeably lighter than other available days."
        }

        return "\(day.displayName) — lowest load day this week."
    }
}
