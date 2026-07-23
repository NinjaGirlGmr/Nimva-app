import Foundation
import SwiftData

@Model
final class Event {
    var id: UUID = UUID()
    var name: String = ""
    var isFixed: Bool = false

    // Fixed event fields
    var fixedDay: DayOfWeek?
    var startTime: Date?
    var endTime: Date?

    // Flexible event fields
    var preferredWindow: TimePreference?
    var duration: TimeInterval?         // estimated session length in seconds

    // Shared energy fields
    var energyCost: Double = 0.5        // 0.0–1.0, maps to EnergyLabel + fine-tune slider
    var category: String = "General"
    var patternLearningEnabled: Bool = true

    // Recurrence
    var isRecurring: Bool = false
    var recurrenceFrequency: String?    // "weekly", "daily" — kept simple for MVP

    // Future-proofing: reserved for task splitting and deadline scheduling.
    // v1: both are always nil and ignored by the algorithm.
    // v2: algorithm reads these to split a task across multiple days or
    //     constrain placement to before a deadline.
    var totalDuration: TimeInterval?
    var deadline: Date?

    // Only meaningful for flexible events — ignored for fixed.
    // Priority flex events are scheduled before nice-to-do ones.
    var isPriority: Bool = false

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        isFixed: Bool,
        fixedDay: DayOfWeek? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        preferredWindow: TimePreference? = nil,
        duration: TimeInterval? = nil,
        energyCost: Double = 0.5,
        category: String = "General",
        patternLearningEnabled: Bool = true,
        isRecurring: Bool = false,
        recurrenceFrequency: String? = nil,
        totalDuration: TimeInterval? = nil,
        deadline: Date? = nil,
        isPriority: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isFixed = isFixed
        self.fixedDay = fixedDay
        self.startTime = startTime
        self.endTime = endTime
        self.preferredWindow = preferredWindow
        self.duration = duration
        self.energyCost = min(max(energyCost, 0.0), 1.0)
        self.category = category
        self.patternLearningEnabled = patternLearningEnabled
        self.isRecurring = isRecurring
        self.recurrenceFrequency = recurrenceFrequency
        self.totalDuration = totalDuration
        self.deadline = deadline
        self.isPriority = isPriority
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
