import Foundation

// Backs #32 — lets a user export their full week history as CSV via the system share sheet.
// CSV over JSON: the issue's own framing picks it ("CSV preferred for spreadsheet
// compatibility"), and events/weeks are two genuinely different record shapes, so keeping them
// as two separate, properly-columned CSV files (shared together via one multi-item share
// sheet) is simpler and more readable than either force-fitting both shapes into one file or
// reaching for a zip archive just to bundle them.
//
// No backend involved — purely a local read-and-format of data already in the ModelContext,
// written to temp files only for the share sheet to pick up.
enum DataExportService {
    /// All Event records as a CSV table — one row per event, oldest first.
    static func eventsCSV(from events: [Event]) -> String {
        var lines = [
            "Name,Type,Day,Start Time,End Time,Duration (min),Energy Cost,Category,Priority,This Week Only,Due Date,Pinned Day,Created At"
        ]
        for event in events.sorted(by: { $0.createdAt < $1.createdAt }) {
            let type = event.isFixed ? "Fixed" : "Flexible"
            let day = event.isFixed ? (event.fixedDay?.displayName ?? "") : ""
            let start = event.startTime.map(timeString) ?? ""
            let end = event.endTime.map(timeString) ?? ""
            let duration = event.duration.map { String(Int($0 / 60)) } ?? ""
            let priority = event.isPriority ? "Yes" : "No"
            // "This week only" mirrors the exact concept the rest of the app uses
            // (Event.specificDate != nil) — see EditEventView's matching toggle.
            let thisWeekOnly = event.specificDate != nil ? "Yes" : "No"
            let due = event.deadline.map(dateString) ?? ""
            let pinned = event.pinnedDay?.displayName ?? ""
            let created = dateString(event.createdAt)

            let fields = [
                event.name, type, day, start, end, duration,
                String(event.energyCost), event.category, priority,
                thisWeekOnly, due, pinned, created,
            ]
            lines.append(fields.map(csvEscape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// All WeekCache records as a CSV table — one row per built week, oldest first.
    static func weekHistoryCSV(from caches: [WeekCache]) -> String {
        var lines = [
            "Week Start,Balance Score,Heavy Days,Check-in Rating,Was Recovery Week,Generated At"
        ]
        for cache in caches.sorted(by: { $0.weekStartDate < $1.weekStartDate }) {
            let heavyDays = cache.heavyDayValues
                .compactMap { DayOfWeek(rawValue: $0)?.displayName }
                .joined(separator: "; ")
            let checkIn = cache.checkInRating.map { String($0) } ?? ""
            let recovery = cache.wasRecoveryWeek ? "Yes" : "No"

            let fields = [
                dateString(cache.weekStartDate), String(cache.balanceScore), heavyDays,
                checkIn, recovery, dateString(cache.generatedAt),
            ]
            lines.append(fields.map(csvEscape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Writes both CSVs to the given directory (the system temp directory by default — the
    /// share sheet only needs the files to exist long enough to be handed off, not to persist)
    /// and returns their URLs, ready to hand to a multi-item share sheet. A fixed filename
    /// (not timestamped) is deliberate: re-exporting just overwrites the same two files rather
    /// than littering the temp directory with one pair per tap.
    static func writeExportFiles(
        events: [Event],
        caches: [WeekCache],
        to directory: URL = FileManager.default.temporaryDirectory
    ) throws -> [URL] {
        let eventsURL = directory.appendingPathComponent("Nimva_Events.csv")
        let weeksURL = directory.appendingPathComponent("Nimva_Week_History.csv")
        try eventsCSV(from: events).write(to: eventsURL, atomically: true, encoding: .utf8)
        try weekHistoryCSV(from: caches).write(to: weeksURL, atomically: true, encoding: .utf8)
        return [eventsURL, weeksURL]
    }

    // MARK: - Formatting

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func dateString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    /// Quotes a field only when it contains a character that would otherwise break CSV
    /// parsing (comma, quote, newline) — a literal quote inside a quoted field is escaped by
    /// doubling it, the standard convention every spreadsheet app expects.
    private static func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
