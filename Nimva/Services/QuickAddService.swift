import Foundation

// Backs QuickAddEventsView — batch-adding several flexible events in one sitting (a pile of
// homework, say) without re-running the full AddEventView form once per item. Pulled out as
// its own testable service, not private view logic, per the project's testing rules.
//
// Energy is still always user-set, never automatic (see CLAUDE.md's non-negotiable rule):
// the caller picks one energy label for the running batch (visibly selected, changeable at
// any point), and each item captures whatever was selected at the moment it was added — this
// is still an affirmative choice, just applied at "batch of one sitting" granularity rather
// than "one picker tap per item," which is the whole point of a quick-add flow.
enum QuickAddService {
    // One item queued for creation. Keeps its own energyCost (not just a shared batch value)
    // so a user who changes the energy picker partway through — sixth worksheet duller than
    // the first five — doesn't retroactively change items already queued.
    struct Item: Identifiable, Equatable {
        let id = UUID()
        var name: String
        var energyCost: Double
    }

    // Trims and validates a raw text-field submission before it becomes a queued Item.
    // Rejects empty/whitespace-only input the same way every other add flow in the app does.
    static func makeItem(rawName: String, energyCost: Double) -> Item? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Item(name: trimmed, energyCost: energyCost)
    }

    // Builds the actual Event models to insert once the batch is confirmed. Every item
    // becomes a flexible event sharing the batch's category and "this week only" scope —
    // same specificDate convention AddEventView uses for a single event (Date() = this week
    // only, nil = recurs every week).
    static func makeEvents(
        from items: [Item],
        category: String,
        isThisWeekOnly: Bool,
        patternLearningEnabled: Bool
    ) -> [Event] {
        items.map { item in
            Event(
                name: item.name,
                isFixed: false,
                specificDate: isThisWeekOnly ? Date() : nil,
                preferredWindow: .any,
                energyCost: item.energyCost,
                category: category,
                patternLearningEnabled: patternLearningEnabled
            )
        }
    }
}
