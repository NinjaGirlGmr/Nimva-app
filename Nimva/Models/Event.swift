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
    // nil (default): recurs every week forever, matching fixedDay — the original,
    // still-default behavior for every manually-added or previously-imported event.
    // Non-nil: this occurrence only applies to the single week containing this date
    // (a one-off calendar import, e.g. a single doctor's appointment) — see
    // SchedulerService.isEventVisible(_:inWeekStarting:).
    var specificDate: Date?

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

    // True for a retroactive "log something that happened" entry rather than something
    // scheduled ahead of time — an unplanned burst of draining work, logged after the fact.
    // Never a placement candidate for SchedulerService.regenerate (it already happened, on
    // a specific day, and isn't "to be scheduled"), but still counts toward that day's real
    // load — see SchedulerService's toLoggedFixedEvent/isLoggedEventVisible.
    var wasLogged: Bool = false

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        isFixed: Bool,
        fixedDay: DayOfWeek? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        specificDate: Date? = nil,
        preferredWindow: TimePreference? = nil,
        duration: TimeInterval? = nil,
        energyCost: Double = 0.5,
        category: String = "General",
        patternLearningEnabled: Bool = true,
        isRecurring: Bool = false,
        recurrenceFrequency: String? = nil,
        totalDuration: TimeInterval? = nil,
        deadline: Date? = nil,
        isPriority: Bool = false,
        wasLogged: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isFixed = isFixed
        self.fixedDay = fixedDay
        self.startTime = startTime
        self.endTime = endTime
        self.specificDate = specificDate
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
        self.wasLogged = wasLogged
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
