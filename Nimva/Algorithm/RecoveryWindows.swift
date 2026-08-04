import Foundation

// Extracts just the time-of-day from a Date, as minutes since midnight (0 = midnight,
// 1439 = 11:59 PM). Event.startTime/endTime only carry a meaningful time-of-day for a
// recurring fixed event — their date component is whatever day they were created or last
// edited on, never "today". Comparing full Dates against `now` silently breaks once any
// time has passed since creation (see SchedulerService.isCompletionPremature's fix earlier
// this session) — always go through this instead of dateComponents(_:from:) inline.
func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
}

// A gap between fixed events on a day, expressed in minute-of-day terms rather than Date,
// for the same reason (see minuteOfDay above).
struct RecoveryWindow: Equatable {
    let startMinuteOfDay: Int
    let endMinuteOfDay: Int
    var durationMinutes: Int { endMinuteOfDay - startMinuteOfDay }
}

// Finds gaps between a day's fixed events that are long enough to actually be a usable
// recovery window, not just a passing period between back-to-back commitments. Deliberately
// only considers fixed events — flexible events don't have a real time slot yet (they're
// placed on a day, not a specific hour), so including them would require guessing where
// they'll actually land, which isn't accurate enough to promise as "free time."
//
// Only returns gaps strictly *between* fixed events — not before the first or after the
// last, since there's no reliable "day starts/ends at X" boundary to anchor those against
// without guessing at someone's actual wake/sleep schedule.
func recoveryWindows(
    fixedEvents: [Event],
    minimumMinutes: Int = 20,
    calendar: Calendar = .current
) -> [RecoveryWindow] {
    let rawIntervals: [(start: Int, end: Int)] = fixedEvents.compactMap { event -> (Int, Int)? in
        guard event.isFixed, let start = event.startTime, let end = event.endTime else { return nil }
        let startMinute = minuteOfDay(start, calendar: calendar)
        let endMinute = minuteOfDay(end, calendar: calendar)
        guard endMinute > startMinute else { return nil }
        return (startMinute, endMinute)
    }.sorted { $0.start < $1.start }

    guard !rawIntervals.isEmpty else { return [] }

    // Merge overlapping/touching intervals first, so overlapping or back-to-back fixed
    // events never produce a false gap between them.
    var merged: [(start: Int, end: Int)] = [rawIntervals[0]]
    for interval in rawIntervals.dropFirst() {
        if interval.start <= merged[merged.count - 1].end {
            merged[merged.count - 1].end = max(merged[merged.count - 1].end, interval.end)
        } else {
            merged.append(interval)
        }
    }

    guard merged.count > 1 else { return [] }

    var windows: [RecoveryWindow] = []
    for i in 0..<(merged.count - 1) {
        let gapStart = merged[i].end
        let gapEnd = merged[i + 1].start
        let duration = gapEnd - gapStart
        if duration >= minimumMinutes {
            windows.append(RecoveryWindow(startMinuteOfDay: gapStart, endMinuteOfDay: gapEnd))
        }
    }
    return windows
}

// "2:15 PM" style formatting for a minute-of-day value, matching the short time style
// used elsewhere in the app (EventCard's subtitleText, etc.).
func formattedMinuteOfDay(_ minuteOfDay: Int, calendar: Calendar = .current) -> String {
    var comps = DateComponents()
    comps.hour = minuteOfDay / 60
    comps.minute = minuteOfDay % 60
    let date = calendar.date(from: comps) ?? Date()
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
