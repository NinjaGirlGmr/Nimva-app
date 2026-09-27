import Testing
import Foundation
@testable import Nimva

@Suite("QuickAddService")
struct QuickAddServiceTests {

    // MARK: - makeItem

    @Test func makeItemTrimsWhitespaceAndSucceeds() {
        let item = QuickAddService.makeItem(rawName: "  Chem worksheet  ", energyCost: 0.5)
        #expect(item?.name == "Chem worksheet")
        #expect(item?.energyCost == 0.5)
    }

    @Test func makeItemRejectsEmptyOrWhitespaceOnlyInput() {
        #expect(QuickAddService.makeItem(rawName: "", energyCost: 0.5) == nil)
        #expect(QuickAddService.makeItem(rawName: "   ", energyCost: 0.5) == nil)
        #expect(QuickAddService.makeItem(rawName: "\n\t", energyCost: 0.5) == nil)
    }

    // MARK: - makeEvents

    @Test func makeEventsProducesOneFlexibleEventPerItem() {
        let items = [
            QuickAddService.Item(name: "Worksheet 1", energyCost: 0.25),
            QuickAddService.Item(name: "Worksheet 2", energyCost: 0.75),
        ]
        let result = QuickAddService.makeEvents(
            from: items,
            category: "School",
            isThisWeekOnly: true,
            patternLearningEnabled: true
        )
        #expect(result.count == 2)
        #expect(result.allSatisfy { !$0.isFixed })
        #expect(result.allSatisfy { $0.category == "School" })
        #expect(result[0].name == "Worksheet 1")
        #expect(abs(result[0].energyCost - 0.25) < 0.0001)
        #expect(abs(result[1].energyCost - 0.75) < 0.0001)
    }

    @Test func thisWeekOnlySetsSpecificDateToToday() {
        let items = [QuickAddService.Item(name: "Essay draft", energyCost: 0.5)]
        let result = QuickAddService.makeEvents(
            from: items, category: "School", isThisWeekOnly: true, patternLearningEnabled: true
        )
        #expect(result[0].specificDate != nil)
        // Same-day check, matching how AddEventView's isThisWeekOnly is verified elsewhere.
        let cal = Calendar.current
        #expect(cal.isDate(result[0].specificDate!, inSameDayAs: Date()))
    }

    @Test func everyWeekLeavesSpecificDateNil() {
        let items = [QuickAddService.Item(name: "Weekly reading", energyCost: 0.5)]
        let result = QuickAddService.makeEvents(
            from: items, category: "School", isThisWeekOnly: false, patternLearningEnabled: true
        )
        #expect(result[0].specificDate == nil)
    }

    @Test func patternLearningFlagIsCarriedOntoEachEvent() {
        let items = [QuickAddService.Item(name: "Lab report", energyCost: 0.5)]
        let onResult = QuickAddService.makeEvents(
            from: items, category: "School", isThisWeekOnly: true, patternLearningEnabled: true
        )
        let offResult = QuickAddService.makeEvents(
            from: items, category: "School", isThisWeekOnly: true, patternLearningEnabled: false
        )
        #expect(onResult[0].patternLearningEnabled == true)
        #expect(offResult[0].patternLearningEnabled == false)
    }

    @Test func emptyItemsProducesNoEvents() {
        let result = QuickAddService.makeEvents(
            from: [], category: "General", isThisWeekOnly: true, patternLearningEnabled: true
        )
        #expect(result.isEmpty)
    }
}
