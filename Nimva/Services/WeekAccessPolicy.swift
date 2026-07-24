import Foundation

// Rolling calendar week (#13): decides how many weeks ahead of "this week" a user can
// view/build, and the display label for a given offset. Kept separate from SchedulerService
// since PRO-tier gating is a different concern than the SwiftData/algorithm bridge.
enum WeekAccessPolicy {

    /// How many weeks ahead of the current week are visible. 0 = this week only.
    /// Free tier: 0 until the current week reaches Thursday, then 1 (Thu/Fri/Sat/Sun all
    /// qualify, since rawValue only increases through the week and Sunday is the transition
    /// day into next week). PRO: always 3 — a flat cap, not a cascading unlock, so a PRO
    /// user can plan ahead any day of the week.
    static func maxVisibleOffset(today: DayOfWeek, isProEnabled: Bool) -> Int {
        if isProEnabled { return 3 }
        return today.rawValue >= DayOfWeek.thursday.rawValue ? 1 : 0
    }

    /// Display label for a given week offset — "This week" / "Next week" / a formatted date
    /// for anything further out.
    static func weekLabel(offset: Int, weekStartDate: Date) -> String {
        switch offset {
        case 0: return "This week"
        case 1: return "Next week"
        default:
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return "Week of \(fmt.string(from: weekStartDate))"
        }
    }
}
