import Foundation

// Backs AddEventView's "Split across days" option (#95's related ask: dividing a big task's
// time across multiple days leading up to its due date). Deliberately a creation-time
// decision, not a Scheduler change: once these exist as ordinary flexible Events (each with
// the same deadline), the existing due-date-aware placement algorithm places every session
// independently — its day-by-day load balancing already tends to spread them across
// different days on its own, since it always looks for the lowest-load eligible day. No
// changes to Scheduler itself were needed to get "spread across days" behavior.
enum TaskSplitService {
    /// Builds `sessionCount` child Events from one task. `sessionCount == 1` returns a single
    /// ordinary event (no "(1/1)" suffix) — the same shape AddEventView would create without
    /// splitting at all, so callers don't need a separate no-split code path.
    static func makeSessions(
        name: String,
        totalDurationMinutes: Int,
        sessionCount: Int,
        energyCost: Double,
        category: String,
        deadline: Date,
        isThisWeekOnly: Bool,
        isPriority: Bool,
        patternLearningEnabled: Bool,
        preferredWindow: TimePreference = .any
    ) -> [Event] {
        let specificDate = isThisWeekOnly ? Date() : nil

        guard sessionCount > 1 else {
            return [Event(
                name: name,
                isFixed: false,
                specificDate: specificDate,
                preferredWindow: preferredWindow,
                duration: TimeInterval(totalDurationMinutes * 60),
                energyCost: energyCost,
                category: category,
                patternLearningEnabled: patternLearningEnabled,
                deadline: deadline,
                isPriority: isPriority
            )]
        }

        // Even split with the remainder folded into the last session, so a duration that
        // doesn't divide evenly (100 min / 3) doesn't just quietly lose those minutes.
        // Remainder is clamped at 0, not just subtracted — the AddEventView UI never lets
        // sessionCount exceed totalDurationMinutes today, but this function doesn't itself
        // enforce that, and a caller that did (sessionCount=5 into a 3-minute task, say)
        // would otherwise get a *negative* remainder folded into the last session — negative
        // minutes on an Event, not just an odd number. Clamping means a degenerate request
        // like that over-allocates slightly (5 sessions of 1 minute instead of fitting inside
        // 3) rather than producing an invalid negative-duration event.
        let baseMinutes = max(1, totalDurationMinutes / sessionCount)
        let remainder = max(0, totalDurationMinutes - (baseMinutes * sessionCount))

        return (1...sessionCount).map { index in
            let minutes = baseMinutes + (index == sessionCount ? remainder : 0)
            return Event(
                name: "\(name) (\(index)/\(sessionCount))",
                isFixed: false,
                specificDate: specificDate,
                preferredWindow: preferredWindow,
                duration: TimeInterval(minutes * 60),
                energyCost: energyCost,
                category: category,
                patternLearningEnabled: patternLearningEnabled,
                deadline: deadline,
                isPriority: isPriority
            )
        }
    }
}
