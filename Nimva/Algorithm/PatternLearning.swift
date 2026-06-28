import Foundation

// Exponential moving average: new = old * 0.7 + rating * 0.3
// No suggestions surface until minimumDataPoints ratings have been recorded.
final class PatternLearner {
    let minimumDataPoints: Int
    private(set) var baseline: Double
    private(set) var recordedCount: Int = 0

    var shouldSuggest: Bool { recordedCount >= minimumDataPoints }

    init(initialBaseline: Double = 0.5, minimumDataPoints: Int = 3) {
        self.baseline = min(max(initialBaseline, 0.0), 1.0)
        self.minimumDataPoints = minimumDataPoints
    }

    func record(rating: Double) {
        baseline = PatternLearner.updateBaseline(current: baseline, newRating: rating)
        recordedCount += 1
    }

    func reset() {
        baseline = 0.5
        recordedCount = 0
    }

    static func updateBaseline(current: Double, newRating: Double) -> Double {
        current * 0.7 + newRating * 0.3
    }
}
