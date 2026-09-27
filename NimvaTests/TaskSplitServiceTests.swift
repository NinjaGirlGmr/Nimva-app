import Testing
import Foundation
@testable import Nimva

@Suite("TaskSplitService")
struct TaskSplitServiceTests {

    private var sampleDeadline: Date { Date().addingTimeInterval(3 * 24 * 3600) }

    @Test func sessionCountOneReturnsSingleUnsuffixedEvent() {
        let result = TaskSplitService.makeSessions(
            name: "Chem project",
            totalDurationMinutes: 90,
            sessionCount: 1,
            energyCost: 0.5,
            category: "School",
            deadline: sampleDeadline,
            isThisWeekOnly: true,
            isPriority: false,
            patternLearningEnabled: true
        )
        #expect(result.count == 1)
        #expect(result[0].name == "Chem project")
        #expect(abs(result[0].duration! - 90 * 60) < 0.01)
    }

    @Test func splitsIntoNSuffixedSessionsWithDivisibleDuration() {
        let result = TaskSplitService.makeSessions(
            name: "Chem project",
            totalDurationMinutes: 90,
            sessionCount: 3,
            energyCost: 0.5,
            category: "School",
            deadline: sampleDeadline,
            isThisWeekOnly: true,
            isPriority: false,
            patternLearningEnabled: true
        )
        #expect(result.count == 3)
        #expect(result.map(\.name) == ["Chem project (1/3)", "Chem project (2/3)", "Chem project (3/3)"])
        // 90 / 3 = 30 minutes each, evenly — no remainder to redistribute.
        for event in result {
            #expect(abs(event.duration! - 30 * 60) < 0.01)
        }
    }

    @Test func remainderMinutesFoldIntoTheLastSession() {
        let result = TaskSplitService.makeSessions(
            name: "Essay",
            totalDurationMinutes: 100,
            sessionCount: 3,
            energyCost: 0.5,
            category: "School",
            deadline: sampleDeadline,
            isThisWeekOnly: true,
            isPriority: false,
            patternLearningEnabled: true
        )
        // 100 / 3 = 33 base, remainder 1 → last session gets 34, none of it silently dropped.
        let totalMinutes = result.reduce(0.0) { $0 + $1.duration! } / 60
        #expect(abs(totalMinutes - 100) < 0.01)
        #expect(abs(result[0].duration! - 33 * 60) < 0.01)
        #expect(abs(result[2].duration! - 34 * 60) < 0.01)
    }

    @Test func everySessionSharesTheSameDeadlineAndCategory() {
        let deadline = sampleDeadline
        let result = TaskSplitService.makeSessions(
            name: "Lab report",
            totalDurationMinutes: 120,
            sessionCount: 4,
            energyCost: 0.75,
            category: "School",
            deadline: deadline,
            isThisWeekOnly: true,
            isPriority: true,
            patternLearningEnabled: false
        )
        #expect(result.allSatisfy { $0.deadline == deadline })
        #expect(result.allSatisfy { $0.category == "School" })
        #expect(result.allSatisfy { $0.isPriority == true })
        #expect(result.allSatisfy { $0.patternLearningEnabled == false })
        #expect(result.allSatisfy { !$0.isFixed })
    }

    @Test func everyWeekOnlyLeavesSpecificDateNil() {
        let result = TaskSplitService.makeSessions(
            name: "Reading",
            totalDurationMinutes: 60,
            sessionCount: 2,
            energyCost: 0.5,
            category: "School",
            deadline: sampleDeadline,
            isThisWeekOnly: false,
            isPriority: false,
            patternLearningEnabled: true
        )
        #expect(result.allSatisfy { $0.specificDate == nil })
    }
}
