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

struct CategoryPattern: Identifiable, Equatable {
    var id: String { category }
    let category: String
    let label: EnergyLabel
    let count: Int
}

// Surfaces a learned baseline per category once it has enough tagged occurrences to be
// meaningful (matches PatternService's own default minimumPoints). "General" is excluded —
// it's the fallback every event gets when no real category was chosen, so a baseline there
// isn't a real signal. Sorted by count so the best-supported pattern shows first.
func categoryPatterns(baselines: [String: Double], counts: [String: Int], minimumPoints: Int = 3) -> [CategoryPattern] {
    counts.compactMap { category, count -> CategoryPattern? in
        guard count >= minimumPoints, category != "General", let baseline = baselines[category] else { return nil }
        return CategoryPattern(category: category, label: EnergyLabel.closest(to: baseline), count: count)
    }
    .sorted { $0.count > $1.count }
}
