import Foundation
import SwiftData

// Stores the computed week result so screens read from cache rather than
// re-running the algorithm. Invalidated when any event is added, edited, or deleted.
@Model
final class WeekCache {
    var weekStartDate: Date
    var placementsJSON: String      // JSON-encoded [{eventId, dayRawValue}]
    var balanceScore: Double
    var heavyDayValues: [Int]       // DayOfWeek.rawValue for each flagged day
    var generatedAt: Date

    // Written by the weekly check-in flow. nil means the user hasn't checked in yet.
    // 0.0 = not draining at all, 1.0 = very draining — same scale as energyCost.
    var checkInRating: Double?
    var checkInHardestDayRawValue: Int?     // DayOfWeek.rawValue, nil if no standout day
    var checkInCompletedAt: Date?

    // JSON-encoded [String] of UUIDs marked complete during this week.
    // Cleared implicitly when the week is rebuilt (new WeekCache replaces old one).
    var completedEventIdsJSON: String = "[]"

    // True when the algorithm classified this as a light week at generation time.
    // Drives the recovery check-in branch and Insights recovery pattern.
    var wasRecoveryWeek: Bool = false

    // Set by the check-in flow when wasRecoveryWeek is true.
    // 1 = yes felt like rest, 2 = somewhat, 3 = no, still drained
    var recoveryCheckInRaw: Int? = nil

    // Set on light weeks — a small behavioral experiment suggested for the week.
    // Deterministic per week start date; carried forward on rebuilds so it doesn't reshuffle.
    var experimentText: String? = nil

    // Check-in result for the experiment.
    // 1 = tried it and it helped, 2 = tried it but unsure, 3 = didn't get to it
    var experimentTriedRaw: Int? = nil

    init(weekStartDate: Date, placementsJSON: String, balanceScore: Double, heavyDayValues: [Int]) {
        self.weekStartDate = weekStartDate
        self.placementsJSON = placementsJSON
        self.balanceScore = balanceScore
        self.heavyDayValues = heavyDayValues
        self.generatedAt = Date()
    }
}
