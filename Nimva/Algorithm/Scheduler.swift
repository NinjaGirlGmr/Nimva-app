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
            // Place on the lowest-load eligible day.
            // Time preference is stored on PlacedEvent for the UI but does not
            // constrain day selection in v1 — to be added once we validate the
            // base algorithm with real schedules.
            guard let bestDay = eligibleDays.min(by: {
                dailyLoads[$0, default: 0.0] < dailyLoads[$1, default: 0.0]
            }) else {
                overflow.append(event)
                continue
            }

            placed.append(PlacedEvent(event: event, day: bestDay))
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
}
