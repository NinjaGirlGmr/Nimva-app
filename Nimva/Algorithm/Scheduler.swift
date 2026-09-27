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
        // Use orderedForLocale so Sunday (rawValue 7) is treated as the FIRST day in US-locale
        // weeks (not the last), preventing placement on a day that already ended.
        let eligibleDays: [DayOfWeek]
        if let from = today {
            let ordered = DayOfWeek.orderedForLocale
            let fromIdx = ordered.firstIndex(of: from) ?? 0
            eligibleDays = Array(ordered[fromIdx...])
        } else {
            eligibleDays = DayOfWeek.allCases
        }

        // Priority-first, then LPT within each group: must-do events claim the lightest
        // available days before nice-to-do events can fill them.
        let sorted = flexible.sorted { lhs, rhs in
            if lhs.isPriority != rhs.isPriority { return lhs.isPriority }
            return lhs.energyCost > rhs.energyCost
        }

        var placed: [PlacedEvent] = []
        var overflow: [FlexibleEvent] = []

        for event in sorted {
            // Due-date constraint (#95): an event with a deadline can only land on or before
            // that day, even if a lighter day exists later in the week — being on time matters
            // more than being on the lightest day. Falls back to the full eligibleDays list
            // when there's no deadline, or when the deadline day itself isn't one of today's
            // remaining eligible days (already unmeetable by the time this build ran — rather
            // than silently overflow something the user still needs done, still place it as
            // soon as possible instead of pretending the constraint can be honored).
            let deadlineConstrained = deadlineConstrainedDays(for: event, within: eligibleDays)

            // Recovery gap protection (#60): prefer non-heavy days so flexible events
            // don't pile onto days that are already at the heavy threshold. If every
            // eligible day is already heavy, fall back to the least-loaded option
            // rather than overflowing — the user's schedule is just packed.
            let nonHeavy = deadlineConstrained.filter { dailyLoads[$0, default: 0.0] < heavyDayThreshold }
            let allEligibleWereHeavy = nonHeavy.isEmpty
            let candidates = allEligibleWereHeavy ? deadlineConstrained : nonHeavy

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
                allEligibleWereHeavy: allEligibleWereHeavy,
                deadlineDay: event.deadlineDay
            )
            placed.append(PlacedEvent(event: event, day: bestDay, reason: reason))
            dailyLoads[bestDay, default: 0.0] += event.energyCost
        }

        // Hard block: remove any placement that ended up outside eligibleDays.
        // Candidates are always drawn from eligibleDays so this should be a no-op in practice,
        // but it prevents any cached stale placement from surviving a fresh build.
        let eligibleSet = Set(eligibleDays)
        placed = placed.filter { eligibleSet.contains($0.day) }

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

    // MARK: - Due-date constraint (#95)

    /// Narrows the full eligibleDays list down to "today (or later) through the deadline
    /// day," inclusive — an event due Thursday can still land Monday–Thursday, just never
    /// Friday–Sunday. `eligibleDays` is already ordered chronologically starting from today
    /// (see generateWeek), so this is just a prefix slice up to the deadline's index.
    static func deadlineConstrainedDays(for event: FlexibleEvent, within eligibleDays: [DayOfWeek]) -> [DayOfWeek] {
        guard let deadlineDay = event.deadlineDay,
              let deadlineIndex = eligibleDays.firstIndex(of: deadlineDay)
        else { return eligibleDays }
        return Array(eligibleDays[...deadlineIndex])
    }

    // MARK: - Placement reason (#62)

    /// Produces a one-line factual explanation of why this day was chosen.
    /// Priority order:
    ///   1. Placed exactly on its due day — no more room to move it, worth flagging plainly.
    ///   2. All eligible days were heavy — honest fallback message.
    ///   3. Only one candidate — lightest available day.
    ///   4. Clear load gap (≥ 0.5) vs the next lightest option — "noticeably lighter."
    ///   5. Standard lowest-load pick.
    private static func placementReason(
        day: DayOfWeek,
        candidates: [DayOfWeek],
        dailyLoads: [DayOfWeek: Double],
        allEligibleWereHeavy: Bool,
        deadlineDay: DayOfWeek? = nil
    ) -> String {
        if let deadlineDay, day == deadlineDay {
            return "\(day.displayName) — placed on its due day, no more room to move this one."
        }

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
