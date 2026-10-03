import Foundation

// Backs #79 — scores the candidate time windows a fixed event offers (Event's
// candidateStartTimes/candidateEndTimes) and picks the one that fits best into the rest of
// that day's already-fixed schedule.
//
// Deliberately NOT a day-level balance-score comparison, despite #79's original framing —
// balance score is computed per day, and every candidate for one event is, by definition, on
// the SAME day, so day-level load is identical no matter which candidate wins; it can never
// actually differentiate between them. What genuinely differs between two same-day time
// slots is local clustering: whether the slot sits right up against another draining event
// with no breathing room, or has space around it. Reuses the same "draining" (energyCost >
// 0.5) + adjacency reasoning IntelligenceService.backToBackStreak already uses for day-note
// text, rather than inventing a second metric for the same underlying question.
enum CandidateWindowService {
    /// One window option — a paired start/end.
    struct Window: Equatable {
        let start: Date
        let end: Date
    }

    /// Picks the best candidate window for one event, scored against the day's other already-
    /// placed fixed events. Returns nil only when `candidates` is empty (nothing to choose
    /// from) — every other outcome always returns a real Window.
    ///
    /// Scoring, in order:
    ///   1. A candidate that overlaps an existing event is excluded outright — not just
    ///      penalized, since double-booking isn't a worse option, it's an invalid one.
    ///   2. Among the valid remainder, prefer the one with the largest minimum gap to its
    ///      nearest draining neighbor on either side. A side with no draining neighbor at all
    ///      imposes no constraint from that side (treated as unlimited room), so a window with
    ///      only non-draining company nearby isn't penalized for being "close" to something
    ///      that isn't actually costing the day anything.
    ///   3. If every candidate overlaps something, falls back to the first candidate — a
    ///      degenerate case (every offered window genuinely conflicts) worth still returning
    ///      *something* for rather than silently producing no schedule.
    static func bestWindow(
        candidates: [Window],
        otherEventsOnDay: [Event],
        calendar: Calendar = .current
    ) -> Window? {
        guard !candidates.isEmpty else { return nil }

        // minuteOfDay, not raw Date comparison — see its own doc comment: an Event's
        // startTime/endTime only carries a meaningful time-of-day, its date component is
        // whatever day it happened to be created/edited on, not necessarily shared between
        // two different events being compared here.
        // Assumes end > start within a single day (no midnight-crossing windows) — the only
        // way candidates currently reach this function is AddEventView/EditEventView's rows,
        // which already filter to end > start before a window counts as valid, so a
        // wrapping window (e.g. 11 PM – 1 AM) can't arrive here today. Worth remembering if
        // overnight candidate windows are ever added — minuteOfDay comparison would need to
        // handle the wraparound explicitly.
        func minutes(_ window: Window) -> (start: Int, end: Int) {
            (minuteOfDay(window.start, calendar: calendar), minuteOfDay(window.end, calendar: calendar))
        }

        let otherWindows: [(start: Int, end: Int, isDraining: Bool)] = otherEventsOnDay.compactMap { event in
            guard let start = event.startTime, let end = event.endTime else { return nil }
            return (minuteOfDay(start, calendar: calendar), minuteOfDay(end, calendar: calendar), event.energyCost > 0.5)
        }

        let validCandidates = candidates.filter { candidate in
            let c = minutes(candidate)
            return !otherWindows.contains { c.start < $0.end && $0.start < c.end }
        }
        guard !validCandidates.isEmpty else { return candidates.first }

        let drainingNeighbors = otherWindows.filter(\.isDraining)

        func minGapMinutes(_ candidate: Window) -> Int {
            let c = minutes(candidate)
            let gapBefore = drainingNeighbors.filter { $0.end <= c.start }.map { c.start - $0.end }.min() ?? .max
            let gapAfter = drainingNeighbors.filter { $0.start >= c.end }.map { $0.start - c.end }.min() ?? .max
            return min(gapBefore, gapAfter)
        }

        return validCandidates.max { minGapMinutes($0) < minGapMinutes($1) }
    }
}
