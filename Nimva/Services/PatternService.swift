import Foundation

// Persists per-category energy baselines across app launches using UserDefaults.
// PatternLearner runs the EMA formula; PatternService stores the result.
// Baselines are keyed by event category (e.g. "School", "Work", "General").
final class PatternService {
    static let shared = PatternService()

    private let baselineKey = "nimva_category_baselines"
    private let countKey    = "nimva_category_counts"

    // Current learned baselines: [category → EMA baseline (0.0–1.0)]
    var baselines: [String: Double] {
        get { decode(key: baselineKey) ?? [:] }
        set { encode(newValue, key: baselineKey) }
    }

    // How many data points have been recorded per category
    var recordedCounts: [String: Int] {
        get { decode(key: countKey) ?? [:] }
        set { encode(newValue, key: countKey) }
    }

    // Updates the EMA baseline for a category using PatternLearner's formula.
    // energyCost is on the same 0.0–1.0 scale as Event.energyCost.
    func record(energyCost: Double, for category: String) {
        var b = baselines
        var c = recordedCounts
        let current = b[category] ?? 0.5
        b[category] = PatternLearner.updateBaseline(current: current, newRating: energyCost)
        c[category] = (c[category] ?? 0) + 1
        baselines = b
        recordedCounts = c
    }

    // Returns a learned baseline if enough data points exist, otherwise nil.
    // Callers should fall back to the user-set energyCost when this returns nil.
    func baseline(for category: String, minimumPoints: Int = 3) -> Double? {
        guard let count = recordedCounts[category], count >= minimumPoints else { return nil }
        return baselines[category]
    }

    // Clears all learned baselines and counts — called by Settings "Reset patterns".
    func reset() {
        UserDefaults.standard.removeObject(forKey: baselineKey)
        UserDefaults.standard.removeObject(forKey: countKey)
    }

    // MARK: Private

    private func decode<T: Decodable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        let data = try? JSONEncoder().encode(value)
        UserDefaults.standard.set(data, forKey: key)
    }
}
