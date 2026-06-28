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

    init(weekStartDate: Date, placementsJSON: String, balanceScore: Double, heavyDayValues: [Int]) {
        self.weekStartDate = weekStartDate
        self.placementsJSON = placementsJSON
        self.balanceScore = balanceScore
        self.heavyDayValues = heavyDayValues
        self.generatedAt = Date()
    }
}
