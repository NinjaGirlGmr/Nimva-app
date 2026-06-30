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

    init(weekStartDate: Date, placementsJSON: String, balanceScore: Double, heavyDayValues: [Int]) {
        self.weekStartDate = weekStartDate
        self.placementsJSON = placementsJSON
        self.balanceScore = balanceScore
        self.heavyDayValues = heavyDayValues
        self.generatedAt = Date()
    }
}
