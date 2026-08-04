import Foundation

// Where a "now" marker should render in a day's chronologically-sorted event list.
// .beforeEvent(id) means insert directly above that event's row; .afterAll means every
// fixed event for the day has already started, so the marker goes at the bottom.
// A nil result from nowMarkerPosition(_:) means "don't show a marker at all" — no fixed
// events to anchor against, same reasoning as recoveryWindows.
enum NowMarkerPosition: Equatable {
    case beforeEvent(UUID)
    case afterAll
}

// Deliberately only considers fixed events, same constraint as recoveryWindows: flexible
// events are placed on a day, not a specific hour, so there's nothing to compare "now"
// against for them without guessing. Logged (retroactive) entries are excluded too — they
// represent something already over, not a point on today's remaining timeline.
func nowMarkerPosition(
    fixedEvents: [Event],
    now: Date = Date(),
    calendar: Calendar = .current
) -> NowMarkerPosition? {
    let sorted = fixedEvents.compactMap { event -> (id: UUID, startMinute: Int)? in
        guard event.isFixed, let start = event.startTime else { return nil }
        return (event.id, minuteOfDay(start, calendar: calendar))
    }.sorted { $0.startMinute < $1.startMinute }

    guard !sorted.isEmpty else { return nil }

    let nowMinute = minuteOfDay(now, calendar: calendar)
    if let next = sorted.first(where: { $0.startMinute > nowMinute }) {
        return .beforeEvent(next.id)
    }
    return .afterAll
}
