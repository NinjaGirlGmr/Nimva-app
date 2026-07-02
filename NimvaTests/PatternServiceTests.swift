import Testing
import Foundation
@testable import Nimva

// MARK: - PatternService

// .serialized prevents parallel test execution — necessary because PatternService.shared
// writes to UserDefaults and tests would stomp each other if run concurrently.
@Suite("PatternService — EMA Baselines", .serialized)
struct PatternServiceTests {

    // Start each test with a clean slate
    init() { PatternService.shared.reset() }

    @Test func baselineNilBeforeMinimumPoints() {
        PatternService.shared.record(energyCost: 0.8, for: "School")
        PatternService.shared.record(energyCost: 0.7, for: "School")
        // 2 data points, default minimum is 3
        #expect(PatternService.shared.baseline(for: "School") == nil)
    }

    @Test func baselineAvailableAtMinimumPoints() {
        for _ in 0..<3 { PatternService.shared.record(energyCost: 0.8, for: "School") }
        #expect(PatternService.shared.baseline(for: "School") != nil)
    }

    @Test func emaMovesTowardHighValues() {
        // Default starts at 0.5; pushing 1.0 repeatedly should pull it above 0.5
        for _ in 0..<5 { PatternService.shared.record(energyCost: 1.0, for: "Sports") }
        let baseline = PatternService.shared.baseline(for: "Sports", minimumPoints: 1)!
        #expect(baseline > 0.5)
    }

    @Test func emaMovesTowardLowValues() {
        for _ in 0..<5 { PatternService.shared.record(energyCost: 0.0, for: "Personal") }
        let baseline = PatternService.shared.baseline(for: "Personal", minimumPoints: 1)!
        #expect(baseline < 0.5)
    }

    @Test func emaConvergesGradually() {
        // After a single recording, the EMA should be between the prior (0.5) and the new value
        PatternService.shared.record(energyCost: 1.0, for: "Work")
        let baseline = PatternService.shared.baseline(for: "Work", minimumPoints: 1)!
        // Formula: 0.5 * 0.7 + 1.0 * 0.3 = 0.65
        #expect(abs(baseline - 0.65) < 0.001)
    }

    @Test func resetClearsAllData() {
        PatternService.shared.record(energyCost: 0.8, for: "School")
        PatternService.shared.record(energyCost: 0.6, for: "Sports")
        PatternService.shared.reset()
        #expect(PatternService.shared.baselines.isEmpty)
        #expect(PatternService.shared.recordedCounts.isEmpty)
    }

    @Test func resetMakesBaselineNilAgain() {
        for _ in 0..<5 { PatternService.shared.record(energyCost: 0.9, for: "School") }
        #expect(PatternService.shared.baseline(for: "School") != nil)
        PatternService.shared.reset()
        #expect(PatternService.shared.baseline(for: "School") == nil)
    }

    @Test func categoriesAreIndependent() {
        for _ in 0..<3 { PatternService.shared.record(energyCost: 0.0, for: "Easy") }
        for _ in 0..<3 { PatternService.shared.record(energyCost: 1.0, for: "Hard") }
        let easy = PatternService.shared.baseline(for: "Easy")!
        let hard = PatternService.shared.baseline(for: "Hard")!
        #expect(easy < hard)
    }

    @Test func extremeValuesAreStoredCorrectly() {
        for _ in 0..<3 { PatternService.shared.record(energyCost: 0.0, for: "ZeroCost") }
        for _ in 0..<3 { PatternService.shared.record(energyCost: 1.0, for: "FullCost") }
        #expect(PatternService.shared.baseline(for: "ZeroCost")! < 0.5)
        #expect(PatternService.shared.baseline(for: "FullCost")! > 0.5)
    }

    @Test func customMinimumPointsRespected() {
        PatternService.shared.record(energyCost: 0.8, for: "School")
        // minimumPoints: 1 → should return data
        #expect(PatternService.shared.baseline(for: "School", minimumPoints: 1) != nil)
        // minimumPoints: 2 → still nil (only 1 point recorded)
        #expect(PatternService.shared.baseline(for: "School", minimumPoints: 2) == nil)
    }

    @Test func countIncreasesWithEachRecord() {
        PatternService.shared.record(energyCost: 0.5, for: "School")
        PatternService.shared.record(energyCost: 0.5, for: "School")
        #expect(PatternService.shared.recordedCounts["School"] == 2)
    }
}

