import Foundation

// IntelligenceService produces timing-specific observations that the
// load-level EnergyZoneCard can't make — back-to-back streaks, recovery
// windows, week-level summaries. All functions are pure: [Event] in, String out.
enum IntelligenceService {

    // MARK: - Back-to-back detection (#58)

    /// Returns the longest consecutive run of high-cost fixed events (energyCost > 0.5)
    /// with fewer than 15 minutes between them. Requires startTime + endTime on each event.
    static func backToBackStreak(events: [Event]) -> Int {
        let timed = events
            .filter { $0.isFixed && $0.startTime != nil && $0.endTime != nil }
            .sorted { $0.startTime! < $1.startTime! }

        guard !timed.isEmpty else { return 0 }

        var maxStreak = 0
        var streak = 0

        for i in 0..<timed.count {
            let curr = timed[i]
            if curr.energyCost > 0.5 {
                if i == 0 {
                    streak = 1
                } else {
                    let prev = timed[i - 1]
                    let gap = curr.startTime!.timeIntervalSince(prev.endTime!)
                    if prev.energyCost > 0.5 && gap < 15 * 60 {
                        streak += 1
                    } else {
                        maxStreak = max(maxStreak, streak)
                        streak = 1
                    }
                }
            } else {
                maxStreak = max(maxStreak, streak)
                streak = 0
            }
        }
        return max(maxStreak, streak)
    }

    // MARK: - Recovery window detection (#55)

    struct RecoveryWindow {
        let start: Date
        let durationMinutes: Int
    }

    /// Finds gaps between fixed events that are at least minGapMinutes long.
    /// Returns windows sorted by start time, largest first within the same day.
    static func recoveryWindows(events: [Event], minGapMinutes: Int = 15) -> [RecoveryWindow] {
        let timed = events
            .filter { $0.isFixed && $0.startTime != nil && $0.endTime != nil }
            .sorted { $0.startTime! < $1.startTime! }

        guard timed.count >= 2 else { return [] }

        let minGap = TimeInterval(minGapMinutes * 60)
        var windows: [RecoveryWindow] = []

        for i in 1..<timed.count {
            let gapStart = timed[i - 1].endTime!
            let gapEnd   = timed[i].startTime!
            let duration = gapEnd.timeIntervalSince(gapStart)
            if duration >= minGap {
                windows.append(RecoveryWindow(start: gapStart, durationMinutes: Int(duration / 60)))
            }
        }
        return windows.sorted { $0.durationMinutes > $1.durationMinutes }
    }

    // MARK: - Daily Ember note (#53)

    /// Returns a timing-specific observation about the day's events, or "" if
    /// there's nothing more specific than what EnergyZoneCard already shows.
    /// Only surfaces when back-to-back or recovery windows can be named precisely.
    static func dailyNote(events: [Event]) -> String {
        guard !events.isEmpty else { return "" }

        let fmt = DateFormatter()
        fmt.timeStyle = .short

        let streak  = backToBackStreak(events: events)
        let windows = recoveryWindows(events: events)
        let drainingCount = events.filter { $0.energyCost > 0.5 }.count

        // Back-to-back streak is the most important signal — name it with timing
        if streak >= 3 {
            let lastDrainingEnd = events
                .filter { $0.isFixed && $0.energyCost > 0.5 && $0.endTime != nil }
                .sorted { $0.endTime! > $1.endTime! }
                .first?.endTime
            if let end = lastDrainingEnd {
                return "\(streak) draining events back to back — no real gap until \(fmt.string(from: end))."
            }
            return "\(streak) draining events back to back with no meaningful gap."
        }

        // Recovery window + at least one draining event — surface the gap specifically
        if let window = windows.first, drainingCount >= 1 {
            return "You have \(window.durationMinutes)m free at \(fmt.string(from: window.start)). That's a recovery window."
        }

        // Many draining events but no timed recovery gap found
        if drainingCount >= 3 {
            return "\(drainingCount) draining events today — no clear gaps between them."
        }

        // Nothing specific enough to add beyond what EnergyZoneCard already shows
        return ""
    }

    // MARK: - Week load summary (#54)

    /// One honest sentence about the whole week's energy picture.
    static func weekLoadSummary(dailyLoads: [DayOfWeek: Double]) -> String {
        let values = dailyLoads.values
        guard values.contains(where: { $0 > 0 }) else { return "" }

        let total    = values.reduce(0, +)
        let heaviest = dailyLoads.max(by: { $0.value < $1.value })?.key

        switch total {
        case ..<2.0:
            return "Light week overall."
        case ..<5.0:
            let name = heaviest?.displayName ?? "one day"
            return "Moderate week — \(name) carries the most load."
        default:
            let name = heaviest?.displayName ?? "one day"
            return "Heavy week — \(name) is the hardest day."
        }
    }

    // MARK: - Lightest upcoming day (#59)

    /// The day from today onward with the lowest non-zero energy load.
    /// Returns nil if no upcoming days have any load.
    static func lightestUpcomingDay(dailyLoads: [DayOfWeek: Double], from today: DayOfWeek) -> DayOfWeek? {
        let upcoming = dailyLoads.filter { $0.key.rawValue >= today.rawValue && $0.value > 0 }
        return upcoming.min(by: { $0.value < $1.value })?.key
    }

    // MARK: - Category breakdown (#61)

    /// Returns the category responsible for the most energy drain this week, and its share.
    /// Returns nil if there are fewer than 3 draining events or no clear dominant category.
    static func dominantDrainCategory(events: [Event]) -> (category: String, share: Double)? {
        let draining = events.filter { $0.energyCost > 0.5 }
        guard draining.count >= 3 else { return nil }

        var totals: [String: Double] = [:]
        for event in draining {
            totals[event.category, default: 0] += event.energyCost
        }

        let weekTotal = events.reduce(0) { $0 + $1.energyCost }
        guard weekTotal > 0,
              let top = totals.max(by: { $0.value < $1.value }),
              top.value / weekTotal > 0.5
        else { return nil }

        return (category: top.key, share: top.value / weekTotal)
    }
}
