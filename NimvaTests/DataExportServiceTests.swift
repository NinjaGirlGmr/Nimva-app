import Testing
import Foundation
@testable import Nimva

@Suite("DataExportService — events CSV")
struct DataExportEventsCSVTests {

    @Test func headerRowIsAlwaysPresent() {
        let csv = DataExportService.eventsCSV(from: [])
        #expect(csv == "Name,Type,Day,Start Time,End Time,Duration (min),Energy Cost,Category,Priority,This Week Only,Due Date,Pinned Day,Created At")
    }

    @Test func fixedEventRowIncludesDayAndTimes() {
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let end = Calendar.current.date(bySettingHour: 10, minute: 30, second: 0, of: Date())!
        let event = Event(name: "Math Class", isFixed: true, fixedDay: .tuesday, startTime: start, endTime: end, energyCost: 0.6)

        let rows = DataExportService.eventsCSV(from: [event]).components(separatedBy: "\n")
        #expect(rows.count == 2)
        #expect(rows[1].hasPrefix("Math Class,Fixed,Tuesday,09:00,10:30,"))
    }

    @Test func flexibleEventRowOmitsDayButIncludesCategoryAndEnergy() {
        let event = Event(name: "Essay", isFixed: false, energyCost: 0.75, category: "School")
        let rows = DataExportService.eventsCSV(from: [event]).components(separatedBy: "\n")
        #expect(rows[1].hasPrefix("Essay,Flexible,,,,"))
        #expect(rows[1].contains("0.75"))
        #expect(rows[1].contains("School"))
    }

    @Test func pinnedDayAppearsInItsOwnColumn() {
        let event = Event(name: "Gym", isFixed: false, energyCost: 0.4, pinnedDay: .monday)
        let rows = DataExportService.eventsCSV(from: [event]).components(separatedBy: "\n")
        #expect(rows[1].contains(",Monday,"))
    }

    @Test func commaInNameIsQuotedAndEscaped() {
        let event = Event(name: "Chores, laundry", isFixed: false, energyCost: 0.2)
        let rows = DataExportService.eventsCSV(from: [event]).components(separatedBy: "\n")
        #expect(rows[1].hasPrefix("\"Chores, laundry\","))
    }

    @Test func rowsAreOrderedOldestFirst() {
        let older = Event(name: "First", isFixed: false, energyCost: 0.5)
        Thread.sleep(forTimeInterval: 0.01)
        let newer = Event(name: "Second", isFixed: false, energyCost: 0.5)
        let rows = DataExportService.eventsCSV(from: [newer, older]).components(separatedBy: "\n")
        #expect(rows[1].hasPrefix("First,"))
        #expect(rows[2].hasPrefix("Second,"))
    }
}

@Suite("DataExportService — week history CSV")
struct DataExportWeekHistoryCSVTests {

    @Test func headerRowIsAlwaysPresent() {
        let csv = DataExportService.weekHistoryCSV(from: [])
        #expect(csv == "Week Start,Balance Score,Heavy Days,Check-in Rating,Was Recovery Week,Generated At")
    }

    @Test func rowIncludesHeavyDayNamesJoined() {
        let cache = WeekCache(
            weekStartDate: SchedulerService.weekStart(),
            placementsJSON: "[]",
            balanceScore: 1.25,
            heavyDayValues: [DayOfWeek.monday.rawValue, DayOfWeek.wednesday.rawValue]
        )
        let rows = DataExportService.weekHistoryCSV(from: [cache]).components(separatedBy: "\n")
        #expect(rows[1].contains("Monday; Wednesday"))
        #expect(rows[1].contains("1.25"))
    }

    @Test func noCheckInRatingLeavesFieldBlank() {
        let cache = WeekCache(weekStartDate: SchedulerService.weekStart(), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        let rows = DataExportService.weekHistoryCSV(from: [cache]).components(separatedBy: "\n")
        // Empty Heavy Days + empty Check-in Rating back to back: "...,,,"
        #expect(rows[1].contains(",,,No,"))
    }

    @Test func rowsAreOrderedOldestFirst() {
        let older = WeekCache(weekStartDate: SchedulerService.weekStart(offsetWeeks: -2), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        let newer = WeekCache(weekStartDate: SchedulerService.weekStart(), placementsJSON: "[]", balanceScore: 0, heavyDayValues: [])
        let rows = DataExportService.weekHistoryCSV(from: [newer, older]).components(separatedBy: "\n")
        let olderStart = ISO8601DateFormatter().string(from: older.weekStartDate)
        #expect(rows[1].hasPrefix(olderStart))
    }
}

@Suite("DataExportService — writeExportFiles")
struct DataExportWriteFilesTests {

    @Test func writesBothFilesToTheGivenDirectoryWithExpectedContent() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let event = Event(name: "Reading", isFixed: false, energyCost: 0.3)
        let cache = WeekCache(weekStartDate: SchedulerService.weekStart(), placementsJSON: "[]", balanceScore: 0.5, heavyDayValues: [])

        let urls = try DataExportService.writeExportFiles(events: [event], caches: [cache], to: tempDir)

        #expect(urls.count == 2)
        #expect(urls.contains { $0.lastPathComponent == "Nimva_Events.csv" })
        #expect(urls.contains { $0.lastPathComponent == "Nimva_Week_History.csv" })

        let eventsContent = try String(contentsOf: urls.first { $0.lastPathComponent == "Nimva_Events.csv" }!, encoding: .utf8)
        #expect(eventsContent.contains("Reading"))
        let weeksContent = try String(contentsOf: urls.first { $0.lastPathComponent == "Nimva_Week_History.csv" }!, encoding: .utf8)
        #expect(weeksContent.contains("0.5"))
    }

    @Test func reExportingOverwritesRatherThanAccumulatingFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        _ = try DataExportService.writeExportFiles(events: [Event(name: "A", isFixed: false, energyCost: 0.5)], caches: [], to: tempDir)
        _ = try DataExportService.writeExportFiles(events: [Event(name: "B", isFixed: false, energyCost: 0.5)], caches: [], to: tempDir)

        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        #expect(contents.count == 2)   // still just the one events file + one weeks file
    }
}
