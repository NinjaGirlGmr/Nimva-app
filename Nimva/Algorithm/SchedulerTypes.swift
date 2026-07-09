import Foundation

enum EnergyLabel: Double, CaseIterable, Codable {
    case noEnergy = 0.0
    case alright = 0.25
    case manageable = 0.5
    case takesEffort = 0.75
    case prettyDraining = 1.0

    var cost: Double { rawValue }

    var displayName: String {
        switch self {
        case .noEnergy:      return "No energy"
        case .alright:       return "Alright"
        case .manageable:    return "Manageable"
        case .takesEffort:   return "Takes Effort"
        case .prettyDraining: return "Pretty Draining"
        }
    }
}

enum TimePreference: String, CaseIterable, Codable {
    case morning, afternoon, evening, any

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .any: return "Any time"
        }
    }
}

enum DayOfWeek: Int, CaseIterable, Codable, Hashable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var displayName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    var shortName: String { String(displayName.prefix(3)) }

    // Returns the next day within the same week, or nil for Sunday.
    // Used to look ahead for forward warnings ("tomorrow looks heavy").
    var next: DayOfWeek? { DayOfWeek(rawValue: rawValue + 1) }

    // Week display order that matches the device locale.
    // US default (firstWeekday == 1): Sunday … Saturday.
    // ISO/European (firstWeekday == 2): Monday … Sunday (same as allCases).
    static var orderedForLocale: [DayOfWeek] {
        if Calendar.current.firstWeekday == 1 {
            return [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        }
        return allCases
    }
}

// Which mode a user appears to be in, detected from their schedule data — never asked.
// Drives what the app emphasizes: optimizer tools vs. clarity/recovery messaging.
enum UserType: Equatable {
    case optimizer       // meaningful mix of fixed + flexible; smart placement is the value
    case overloadedFixed // 90%+ fixed events; value shifts to naming the load, not optimizing it
    case patternLearner  // moderate fixed-heavy mix; patterns over time are the main insight
}

struct FixedEvent {
    let id: UUID
    let name: String
    let day: DayOfWeek
    let energyCost: Double

    init(id: UUID = UUID(), name: String, day: DayOfWeek, energyCost: Double) {
        self.id = id
        self.name = name
        self.day = day
        self.energyCost = min(max(energyCost, 0.0), 1.0)
    }
}

struct FlexibleEvent {
    let id: UUID
    let name: String
    let preferredWindow: TimePreference
    let energyCost: Double

    init(id: UUID = UUID(), name: String, preferredWindow: TimePreference = .any, energyCost: Double) {
        self.id = id
        self.name = name
        self.preferredWindow = preferredWindow
        self.energyCost = min(max(energyCost, 0.0), 1.0)
    }
}

struct PlacedEvent {
    let event: FlexibleEvent
    let day: DayOfWeek
}

struct WeekSchedule {
    let fixedEvents: [FixedEvent]
    let placedFlexibleEvents: [PlacedEvent]
    let overflowEvents: [FlexibleEvent]
    let dailyLoads: [DayOfWeek: Double]
    let balanceScore: Double
    let heavyDays: Set<DayOfWeek>
}
